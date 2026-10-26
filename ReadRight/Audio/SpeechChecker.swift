import Foundation
import Speech

/// Checks whether a child said the target word, using Apple's on-device speech recognizer only.
///
/// **Privacy rule.** Apple only honors `requiresOnDeviceRecognition` when the device supports
/// on-device recognition. If it doesn't, the audio could go to Apple's servers. So
/// `isOnDeviceAvailable` must be true before we ever create a request. If it isn't, the games
/// use voice timing only. There is no server fallback anywhere in this app.
@MainActor
final class SpeechChecker {
    /// Listening Lab only: shows what the recognizer heard, on screen. Never stored.
    var onTranscript: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var accepted: Set<String> = []
    private var matched = false
    private var gotTranscript = false
    private var outcome: WordCheck?
    private var waiting: CheckedContinuation<WordCheck, Never>?
    /// Bumped on every new request, so late callbacks from an old request are ignored.
    private var generation = 0

    static var authorization: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    /// `nonisolated` because Apple calls the completion handler on a background queue.
    nonisolated static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    var isOnDeviceAvailable: Bool {
        guard Self.authorization == .authorized, let recognizer else { return false }
        return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
    }

    /// Starts recognizing. Returns the request for the listening engine to feed,
    /// or nil when on-device recognition isn't available.
    func begin(target: String, alsoAccept: [String] = []) -> SFSpeechAudioBufferRecognitionRequest? {
        cancel()
        guard isOnDeviceAvailable, let recognizer else { return nil }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = [target]
        request.taskHint = .search
        request.addsPunctuation = false

        accepted = Set(([target] + alsoAccept).map { $0.lowercased() })
        matched = false
        gotTranscript = false
        outcome = nil
        self.request = request

        let current = generation
        task = recognizer.recognitionTask(with: request, resultHandler: Self.makeResultHandler { [weak self] update in
            self?.handle(update, generation: current)
        })
        return request
    }

    /// Call when the child has stopped talking. Waits briefly for the recognizer's final answer.
    func end(timeout: Duration = .seconds(1.5)) async -> WordCheck {
        guard let request else { return outcome ?? .unavailable }
        request.endAudio()
        if matched { resolve(.matched) }
        if let outcome { return outcome }

        let current = generation
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard let self, current == self.generation else { return }
            // A voice was heard but the recognizer never matched it.
            self.resolve(self.matched ? .matched : .unclear)
        }
        return await withCheckedContinuation { waiting = $0 }
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        request = nil
        waiting?.resume(returning: outcome ?? .unclear)
        waiting = nil
    }

    /// True if any word in `transcript` is one of the accepted spellings. "Frog." and "the frog" match "frog".
    nonisolated static func containsWord(in transcript: String, from accepted: Set<String>) -> Bool {
        transcript.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .contains { accepted.contains(String($0)) }
    }

    private func handle(_ update: RecognitionUpdate, generation updateGeneration: Int) {
        guard updateGeneration == generation, outcome == nil else { return }
        if let best = update.transcripts.first, !best.isEmpty {
            gotTranscript = true
            onTranscript?(best)
        }
        // Look at every alternative the recognizer offers, not only its best guess.
        if update.transcripts.contains(where: { Self.containsWord(in: $0, from: accepted) }) {
            matched = true
        }
        if update.isFinal {
            resolve(matched ? .matched : .unclear)
        } else if let code = update.errorCode {
            // 1110 means "no speech detected": the recognizer worked but found no words.
            // Other errors (1107 is common in the Simulator) mean the recognizer itself isn't working.
            let recognizerWorked = gotTranscript || code == 1110
            resolve(matched ? .matched : (recognizerWorked ? .unclear : .unavailable))
        }
    }

    private func resolve(_ check: WordCheck) {
        guard outcome == nil else { return }
        outcome = check
        generation += 1
        task?.cancel()
        task = nil
        request = nil
        waiting?.resume(returning: check)
        waiting = nil
    }

    private struct RecognitionUpdate: Sendable {
        let transcripts: [String]
        let isFinal: Bool
        let errorCode: Int?
    }

    /// The recognizer calls back on a background queue. Copy out plain values there and hop to the main actor.
    nonisolated private static func makeResultHandler(
        _ deliver: @escaping @Sendable @MainActor (RecognitionUpdate) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        return { result, error in
            let update = RecognitionUpdate(
                transcripts: result?.transcriptions.map(\.formattedString) ?? [],
                isFinal: result?.isFinal ?? false,
                errorCode: error.map { ($0 as NSError).code }
            )
            Task { @MainActor in deliver(update) }
        }
    }
}
