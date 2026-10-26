import Foundation

/// One "say it out loud" attempt: voice-onset timing, plus an on-device word check when available.
///
/// It works like a traffic light, so a child always knows when to talk:
/// 1. **Amber, "Get ready…"** The microphone listens to the quiet room for about half a second
///    to learn its background noise. The word isn't shown yet, so the child stays quiet.
/// 2. **Green, "Your turn!"** The word appears, and timing starts at that exact moment.
/// 3. The child talks. When they stop, the word check gives its answer.
///
/// Word Woods, Echo Cave and the Listening Lab all use this class.
@MainActor
final class ReadAloudTrial {
    enum Progress {
        /// The light turned green and the word is on screen.
        case speakNow(floorDB: Float?, thresholdDB: Float?)
        case voiceStarted(ms: Int)
        case voiceEnded
    }

    struct Outcome {
        /// Milliseconds from the light turning green to the first sound.
        var onsetMs: Int?
        var wordCheck: WordCheck
    }

    private let engine: ListeningEngine
    private let speech: SpeechChecker?
    private let settings: VoiceOnsetDetector.Settings
    private let noResponseAfter: Duration
    private let maxSpeakingSeconds: TimeInterval

    private var detector: VoiceOnsetDetector
    private var continuation: CheckedContinuation<Bool, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var onProgress: ((Progress) -> Void)?
    /// Seconds after `markStimulus` when the light turned green.
    private var revealedAt: TimeInterval?

    /// - Parameters:
    ///   - speech: pass nil for voice timing only (for example, made-up words, which recognizers can't judge).
    ///   - noResponseAfter: give up if no voice starts within this time after the light turns green.
    ///   - maxSpeakingSeconds: stop anyway if sound keeps going this long (a TV in the background).
    init(
        engine: ListeningEngine,
        speech: SpeechChecker?,
        settings: VoiceOnsetDetector.Settings = .singleWord,
        noResponseAfter: Duration = .seconds(8),
        maxSpeakingSeconds: TimeInterval = 5
    ) {
        self.engine = engine
        self.speech = speech
        self.settings = settings
        self.noResponseAfter = noResponseAfter
        self.maxSpeakingSeconds = maxSpeakingSeconds
        self.detector = VoiceOnsetDetector(settings: settings)
    }

    /// Starts in the amber "Get ready" state. The engine must already be listening.
    func run(word: String, alsoAccept: [String] = [], onProgress: @escaping (Progress) -> Void) async -> Outcome {
        self.onProgress = onProgress
        detector = VoiceOnsetDetector(settings: settings)
        detector.listenFrom = .infinity
        revealedAt = nil
        let request = speech?.begin(target: word, alsoAccept: alsoAccept)
        if let request { engine.attachSpeech(request) }

        let heardVoice = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            self.continuation = continuation
            engine.markStimulus { [weak self] time, level in
                self?.handle(time: time, level: level)
            }
            // If the microphone is slow to deliver audio, turn green anyway rather than keep the child waiting.
            let fallback = settings.calibrationDuration + 1.2
            revealTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(fallback))
                guard !Task.isCancelled else { return }
                self?.reveal()
            }
        }

        engine.clearStimulus()
        engine.detachSpeech()
        timeoutTask?.cancel()
        revealTask?.cancel()
        let onsetMs: Int? = {
            guard let onset = detector.onsetTime, let revealedAt else { return nil }
            return Int(((onset - revealedAt) * 1000).rounded())
        }()

        guard heardVoice else {
            speech?.cancel()
            return Outcome(onsetMs: nil, wordCheck: .noResponse)
        }
        onProgress(.voiceEnded)
        guard let speech, request != nil else {
            return Outcome(onsetMs: onsetMs, wordCheck: .unavailable)
        }
        return Outcome(onsetMs: onsetMs, wordCheck: await speech.end())
    }

    /// Stops the trial early, for example when the child leaves the screen.
    func cancel() {
        resume(heardVoice: false)
    }

    private func handle(time: TimeInterval, level: Float) {
        guard continuation != nil else { return }
        for event in detector.process(time: time, levelDB: level) {
            switch event {
            case .calibrated:
                reveal()
            case .onset(let at):
                timeoutTask?.cancel()
                // Safety net: if the microphone stops mid-word (a phone call, the app going to the background),
                // no more audio arrives to finish the trial, so end it after a while anyway.
                let cap = maxSpeakingSeconds + 2
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(cap))
                    guard !Task.isCancelled else { return }
                    self?.resume(heardVoice: true)
                }
                let fromReveal = at - (revealedAt ?? at)
                onProgress?(.voiceStarted(ms: Int((fromReveal * 1000).rounded())))
            case .finished:
                resume(heardVoice: true)
            }
        }
        if let onset = detector.onsetTime, time - onset > maxSpeakingSeconds {
            resume(heardVoice: true)
        }
    }

    /// Green light: show the word and start timing now.
    private func reveal() {
        guard continuation != nil, revealedAt == nil else { return }
        revealTask?.cancel()
        let now = engine.secondsSinceStimulus()
        revealedAt = now
        detector.listenFrom = now
        onProgress?(.speakNow(floorDB: detector.noiseFloorDB, thresholdDB: detector.thresholdDB))
        let limit = noResponseAfter
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: limit)
            guard !Task.isCancelled else { return }
            self?.giveUpIfSilent()
        }
    }

    private func giveUpIfSilent() {
        if detector.onsetTime == nil { resume(heardVoice: false) }
    }

    private func resume(heardVoice: Bool) {
        continuation?.resume(returning: heardVoice)
        continuation = nil
    }
}
