import AVFoundation

/// Pip's voice. One shared synthesizer for the whole app, so two voices never overlap.
///
/// `say` waits until Pip has finished talking, so a game can start timing the moment a word ends.
///
/// Two fixes for words being cut off at the start or end:
/// - The audio session is set up once and never switched while Pip talks (see AudioSessionConfigurator).
/// - Each line starts after a short pause (`preUtteranceDelay`), so the speaker is awake before the first sound.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    /// From Comfort settings. Words a game depends on (`essential`) are spoken even when this is off.
    var promptsEnabled = true

    /// Calm and a little slower than normal speech, so young children can follow.
    static let rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.88
    static let pitch: Float = 1.08

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    /// Held strongly, so its memory address can't be reused by a new line while it's still current.
    private var currentUtterance: AVSpeechUtterance?
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
    ///   - voice: try a different voice once (the voice picker's preview).
    func say(_ text: String, essential: Bool = false, voice: AVSpeechSynthesisVoice? = nil) async {
        stop()
        guard essential || promptsEnabled else { return }
        if AppFlags.silent {
            try? await Task.sleep(for: .milliseconds(300))
            return
        }
        AudioSessionConfigurator.ensureActive()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? PipVoice.current
        utterance.rate = Self.rate
        utterance.pitchMultiplier = Self.pitch
        utterance.preUtteranceDelay = 0.12
        generation += 1
        let line = generation
        currentUtterance = utterance
        // Watchdog: if speech never reports finishing (an interruption, or the audio session failed),
        // don't leave the game waiting forever.
        let limit = 3 + 0.15 * Double(text.count)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(limit))
            guard let self, self.generation == line, self.currentUtterance != nil else { return }
            self.stop()
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        currentUtterance = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        continuation?.resume()
        continuation = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(id) }
    }

    /// Ignores callbacks for utterances that were already replaced by a newer one.
    private func finished(_ id: ObjectIdentifier) {
        guard let current = currentUtterance, ObjectIdentifier(current) == id else { return }
        currentUtterance = nil
        continuation?.resume()
        continuation = nil
    }
}

/// Picks Pip's voice. A grown-up can choose one in Grown-ups → Pip's voice.
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
