import AVFoundation
import Observation
import Speech

/// Owns the microphone.
///
/// One tap on the microphone input feeds two things: a loudness meter, sliced into
/// 10 ms windows, for voice-onset timing; and, when a game asks, Apple's on-device speech recognizer.
///
/// Audio buffers are processed in memory and dropped right away. Nothing is recorded or saved.
@MainActor
@Observable
final class ListeningEngine {
    enum ListeningError: LocalizedError {
        case noPermission, notChosen, noMicrophone

        var errorDescription: String? {
            switch self {
            case .noPermission: "Microphone access is off for ReadRight. Turn it on in the Settings app → ReadRight."
            case .notChosen: "Listening is off. A grown-up can turn on “Listen while my child reads out loud” in Grown-ups → Settings."
            case .noMicrophone: "No microphone was found on this device."
            }
        }
    }

    /// True while the microphone is on. Games show the glowing ear whenever this is true.
    private(set) var isListening = false

    /// The latest loudness in dBFS, for the on-screen meter.
    private(set) var levelDB: Float = AudioLevel.minimumDB

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let speechFeed = SpeechFeed()
    @ObservationIgnored private var windowHandler: ((TimeInterval, Float) -> Void)?
    @ObservationIgnored private var stimulusSeconds: TimeInterval = 0
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []

    static var hasMicPermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    init() {
        let center = NotificationCenter.default
        // A phone call or Siri takes the microphone away. Stop cleanly instead of pretending we're listening.
        // Ignore "interruption ended": there's nothing to stop then.
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            guard type == .began else { return }
            MainActor.assumeIsolated { self?.stop() }
        })
        // Plugging in headphones changes the input format and stops the engine. Restart with the new format.
        notificationTokens.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartAfterConfigurationChange() }
        })
    }

    func start() throws {
        guard !isListening else { return }
        guard Self.hasMicPermission else { throw ListeningError.noPermission }
        guard AudioSessionConfigurator.listeningChosen else { throw ListeningError.notChosen }
        AudioSessionConfigurator.configure()
        guard AVAudioSession.sharedInstance().category == .playAndRecord else { throw ListeningError.noMicrophone }
        try installTapAndStart()
        isListening = true
    }

    private func installTapAndStart() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw ListeningError.noMicrophone }

        let deliver: @Sendable ([LevelWindow]) -> Void = { [weak self] windows in
            Task { @MainActor in self?.receive(windows) }
        }
        input.removeTap(onBus: 0)
        input.installTap(
            onBus: 0, bufferSize: 1024, format: format,
            block: Self.makeTapBlock(sampleRate: format.sampleRate, speechFeed: speechFeed, deliver: deliver)
        )
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        speechFeed.set(nil)
        windowHandler = nil
        isListening = false
        levelDB = AudioLevel.minimumDB
        // The audio session stays as it is, so Pip's next words aren't clipped by a mode switch.
    }

    /// Seconds since `markStimulus`, on the same clock as the microphone timestamps.
    func secondsSinceStimulus() -> TimeInterval {
        AVAudioTime.seconds(forHostTime: mach_absolute_time()) - stimulusSeconds
    }

    /// Marks "the word just appeared on screen". From now on, `handler` gets every
    /// loudness window as (seconds since this moment, dBFS).
    func markStimulus(_ handler: @escaping (TimeInterval, Float) -> Void) {
        stimulusSeconds = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        windowHandler = handler
    }

    func clearStimulus() {
        windowHandler = nil
    }

    /// Sends the same microphone audio to a speech request until `detachSpeech()`.
    func attachSpeech(_ request: SFSpeechAudioBufferRecognitionRequest) {
        speechFeed.set(request)
    }

    func detachSpeech() {
        speechFeed.set(nil)
    }

    private func receive(_ windows: [LevelWindow]) {
        guard isListening else { return }
        if let last = windows.last { levelDB = last.db }
        guard let handler = windowHandler else { return }
        for window in windows {
            let seconds = AVAudioTime.seconds(forHostTime: window.hostTime) - stimulusSeconds
            // Skip audio captured before the word appeared. It was still in flight from the audio thread.
            if seconds >= 0 { handler(seconds, window.db) }
        }
    }

    /// Headphones plugged in or out: the engine stops itself and the input format may change.
    /// Reinstall the tap in place, keeping the audio mode, the current word's timing and its speech request.
    /// Switching modes here would change the route again and could trigger another restart.
    private func restartAfterConfigurationChange() {
        guard isListening, !engine.isRunning else { return }
        do {
            try installTapAndStart()
        } catch {
            stop()
        }
    }

    /// Builds the closure that runs on the real-time audio thread. It's `nonisolated` and
    /// `static` so it can't touch main-actor state by accident. It only measures loudness,
    /// forwards the buffer to speech recognition, and hands the numbers to the main thread.
    nonisolated private static func makeTapBlock(
        sampleRate: Double,
        speechFeed: SpeechFeed,
        deliver: @escaping @Sendable ([LevelWindow]) -> Void
    ) -> AVAudioNodeTapBlock {
        let windowFrames = max(1, Int(sampleRate / 100))  // 10 ms
        return { buffer, when in
            speechFeed.append(buffer)
            guard let samples = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            let bufferHostTime = when.isHostTimeValid
                ? when.hostTime
                : mach_absolute_time() - AVAudioTime.hostTime(forSeconds: Double(frameCount) / sampleRate)

            var windows: [LevelWindow] = []
            windows.reserveCapacity(frameCount / windowFrames + 1)
            var offset = 0
            while offset < frameCount {
                let count = min(windowFrames, frameCount - offset)
                let db = AudioLevel.rmsDB(UnsafeBufferPointer(start: samples + offset, count: count))
                let hostTime = bufferHostTime + AVAudioTime.hostTime(forSeconds: Double(offset) / sampleRate)
                windows.append(LevelWindow(hostTime: hostTime, db: db))
                offset += count
            }
            deliver(windows)
        }
    }
}

/// One 10 ms slice of microphone audio, reduced to a timestamp and a loudness.
struct LevelWindow: Sendable {
    let hostTime: UInt64
    let db: Float
}

/// Hands microphone buffers from the audio thread to the current speech request, if there is one.
final class SpeechFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.withLock { self.request = request }
    }

    /// Appends inside the lock, so a request can't receive audio after the main thread has detached and ended it.
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.withLock { request?.append(buffer) }
    }
}
