import AVFoundation

/// Pip's voice. One shared speaker for the whole app, so two voices never overlap.
///
/// If someone recorded a line in the Voice Studio, Pip plays that real voice. Otherwise the
/// iPhone's speech voice says it. `say` waits until Pip has finished, so a game can start timing
/// the moment a word ends.
///
/// Two fixes for words being cut off at the start or end:
/// - The audio session isn't switched while Pip talks (see AudioSessionConfigurator).
/// - Each spoken line starts after a short pause (`preUtteranceDelay`), so the speaker is awake first.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = Speaker()

    /// From Comfort settings. Words a game depends on (`essential`) are spoken even when this is off.
    var promptsEnabled = true

    /// A little slower than everyday speech, with only a slight lift in pitch.
    /// Bigger pitch changes make the iPhone voices sound strange rather than friendly.
    static let rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.9
    static let pitch: Float = 1.04

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    /// Held strongly, so its memory address can't be reused by a new line while it's still current.
    private var currentUtterance: AVSpeechUtterance?
    private var player: AVAudioPlayer?
    /// Bumped for every line, so an old watchdog can never stop a newer line.
    private var generation = 0

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Loads the voice before the first real line, so that line isn't clipped or delayed.
    func warmUp() {
        guard !AppFlags.silent else { return }
        let utterance = AVSpeechUtterance(string: " ")
        utterance.voice = PipVoice.current
        utterance.volume = 0
        synthesizer.speak(utterance)
    }

    /// - Parameters:
    ///   - essential: a word the game depends on, spoken even when "Pip reads instructions" is off.
    ///   - voice: try a different iPhone voice once (the voice picker's preview). Skips recordings.
    func say(_ text: String, essential: Bool = false, voice: AVSpeechSynthesisVoice? = nil) async {
        stop()
        guard essential || promptsEnabled else { return }
        if AppFlags.silent {
            try? await Task.sleep(for: .milliseconds(300))
            return
        }
        AudioSessionConfigurator.ensureActive()
        generation += 1
        let line = generation

        if voice == nil, let clip = VoiceClips.url(for: text), let player = try? AVAudioPlayer(contentsOf: clip) {
            self.player = player
            player.delegate = self
            startWatchdog(line, seconds: player.duration + 2)
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                if !player.play() { finishLine() }
            }
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? PipVoice.current
        utterance.rate = Self.rate
        utterance.pitchMultiplier = Self.pitch
        utterance.preUtteranceDelay = 0.12
        currentUtterance = utterance
        startWatchdog(line, seconds: 3 + 0.15 * Double(text.count))
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        currentUtterance = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        player?.stop()
        player = nil
        finishLine()
    }

    /// If a line never reports finishing (an interruption, or the audio session failed),
    /// don't leave the game waiting forever.
    private func startWatchdog(_ line: Int, seconds: TimeInterval) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, self.generation == line, self.continuation != nil else { return }
            self.stop()
        }
    }

    private func finishLine() {
        continuation?.resume()
        continuation = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.recordingEnded(id) }
    }

    /// Ignores callbacks for lines that were already replaced by a newer one.
    private func utteranceEnded(_ id: ObjectIdentifier) {
        guard let current = currentUtterance, ObjectIdentifier(current) == id else { return }
        currentUtterance = nil
        finishLine()
    }

    private func recordingEnded(_ id: ObjectIdentifier) {
        guard let current = player, ObjectIdentifier(current) == id else { return }
        player = nil
        finishLine()
    }
}

/// Picks Pip's iPhone voice. A grown-up can choose one in Grown-ups → Pip's voice.
/// Otherwise ReadRight picks the warmest-sounding US English voice installed.
enum PipVoice {
    static let defaultsKey = "pipVoiceIdentifier"

    /// Gentle, natural voices that tend to suit young children, best first.
    private static let preferredNames = ["Zoe", "Ava", "Samantha", "Allison", "Susan", "Nicky", "Evan", "Nathan", "Tom"]

    /// US English voices that sound natural. Novelty voices (bells, whispers, robots)
    /// and the older robotic voices are left out, because they can sound scary to young children.
    static var choices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" }
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
            .filter { !$0.identifier.contains("eloquence") }
            .sorted { rank($0) < rank($1) }
    }

    static var current: AVSpeechSynthesisVoice? {
        if let id = UserDefaults.standard.string(forKey: defaultsKey), let chosen = AVSpeechSynthesisVoice(identifier: id) {
            return chosen
        }
        return choices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    static func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "Premium"
        case .enhanced: "Enhanced"
        default: "Standard"
        }
    }

    /// Premium voices first, then enhanced, then standard. Within each, the preferred names first.
    private static func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
        let quality: Int
        switch voice.quality {
        case .premium: quality = 0
        case .enhanced: quality = 1
        default: quality = 2
        }
        let nameRank = preferredNames.firstIndex { voice.name.hasPrefix($0) } ?? preferredNames.count
        return quality * 100 + nameRank
    }
}
