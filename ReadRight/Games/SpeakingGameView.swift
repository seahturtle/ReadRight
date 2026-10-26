import SwiftUI

/// Word Woods and Echo Cave: activities where the child answers out loud.
///
/// Each item works like a traffic light: Pip talks (Echo Cave only), the light turns amber
/// ("Get ready…") while the microphone learns the room's quiet, then green ("Your turn!") as the
/// word appears. Timing starts at green. If listening is off, a grown-up records what happened instead.
struct SpeakingGameConfig {
    let activity: Activity
    let intro: String
    let items: [SpeakItem]
    let speakNowText: String
    let offText: String
    let doneLine: String

    static func wordWoods(_ age: Profile.AgeBand) -> SpeakingGameConfig {
        SpeakingGameConfig(
            activity: .wordWoods,
            intro: PipLines.wordWoodsIntro,
            items: ItemBank.wordWoods(for: age),
            speakNowText: "Your turn! Read it now.",
            offText: "Read it to your grown-up.",
            doneLine: PipLines.wordWoodsDone
        )
    }

    static func echoCave(_ age: Profile.AgeBand) -> SpeakingGameConfig {
        SpeakingGameConfig(
            activity: .echoCave,
            intro: PipLines.echoCaveIntro,
            // Two practice puzzles first, so children learn the game before anything is recorded.
            items: ItemBank.echoCavePractice + ItemBank.echoCave(for: age),
            speakNowText: "Your turn! Say it now.",
            offText: "Tell your grown-up your answer.",
            doneLine: PipLines.echoCaveDone
        )
    }
}

struct WordWoodsView: View {
    @Environment(ProfileStore.self) private var profiles

    var body: some View {
        SpeakingGameView(config: .wordWoods(profiles.profile.ageBand))
    }
}

struct EchoCaveView: View {
    @Environment(ProfileStore.self) private var profiles

    var body: some View {
        SpeakingGameView(config: .echoCave(profiles.profile.ageBand))
    }
}

struct SpeakingGameView: View {
    let config: SpeakingGameConfig

    @Environment(ObservationStore.self) private var store
    @Environment(ListeningEngine.self) private var engine
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showListeningDetails") private var showDetails = false
    @State private var model: SpeakingGameModel

    init(config: SpeakingGameConfig) {
        self.config = config
        _model = State(initialValue: SpeakingGameModel(config: config))
    }

    var body: some View {
        GameScaffold(activity: config.activity, step: model.lit, total: config.items.count, listening: engine.isListening) {
            switch model.phase {
            case .intro:
                PipSays(config.intro)
                Button("Start") { model.start() }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 24))
                caption

            case .finished:
                PipSays(config.doneLine, mood: .happy)
                Button("Back to the map") { dismiss() }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 22))

            default:
                PipSays(model.bubble, mood: model.phase == .result ? .happy : .listening)
                TalkLight(state: model.talkState, levelDB: engine.levelDB, speakNowText: config.speakNowText, offText: config.offText)
                if config.activity == .echoCave {
                    if model.item.isPractice { Eyebrow(text: "Practice puzzle") }
                    EchoCard(green: model.talkState == .speakNow || model.talkState == .hearing)
                    Button {
                        model.replayPrompt()
                    } label: {
                        Label("Hear it again", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.panel, radius: 14, drop: 4, size: 16))
                    .disabled(!model.canReplay)
                } else {
                    WordCard(
                        word: model.showsWord ? model.item.shown : nil,
                        green: model.talkState == .speakNow || model.talkState == .hearing,
                        creature: model.item.creature
                    )
                }
                if model.isWaitingForNext {
                    Button("Hop on") { model.next() }
                        .buttonStyle(ChunkyButtonStyle(fill: Theme.sun, size: 22))
                    if !model.item.isPractice {
                        GrownUpCheck(mark: $model.grownUpMark, title: model.checkTitle, detail: model.checkDetail)
                    }
                }
                if showDetails {
                    ListeningDetails(
                        levelDB: engine.levelDB,
                        floorDB: model.noiseFloorDB,
                        thresholdDB: model.thresholdDB,
                        onsetMs: model.onsetMs,
                        note: model.phase == .result ? "check: \(model.wordCheck.rawValue)" : nil
                    )
                }
                caption
            }
        }
        .onAppear {
            model.attach(store: store, engine: engine, listeningAllowed: profiles.profile.listenToReading)
        }
        .task {
            if AppFlags.autostart { model.start() } else { await model.introduce() }
        }
        .onDisappear { model.leave() }
    }

    private var caption: some View {
        Text(model.mode.caption)
            .themed(.body, 14)
            .foregroundStyle(Theme.muted)
    }
}

/// Echo Cave's picture. The answer is never shown: this is a listening puzzle, not reading.
private struct EchoCard: View {
    let green: Bool

    var body: some View {
        IslandArt(activity: .echoCave)
            .frame(maxWidth: 220)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(green ? Color(hex: 0xD9F5E9) : Theme.background))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(green ? Theme.mintDark : Theme.ink, style: StrokeStyle(lineWidth: green ? 5 : 4, dash: green ? [] : [10, 7]))
            )
    }
}

@MainActor
@Observable
final class SpeakingGameModel {
    enum Phase: Equatable {
        case intro, pipSpeaking, getReady, speakNow, hearing, thinking, result, askGrownUp(AskReason), finished
    }

    enum AskReason: Equatable {
        case noVoiceHeard, listeningOff
    }

    enum Mode: Equatable {
        case voiceAndWordCheck, voiceOnly, grownUpOnly

        var caption: String {
            switch self {
            case .voiceAndWordCheck: "Listening is on: voice timing and an on-device word check. Audio is never saved."
            case .voiceOnly: "Listening is on: voice timing only. This iPhone can't check words on its own."
            case .grownUpOnly: "Listening is off. A grown-up can turn it on in Grown-ups → Your choices."
            }
        }
    }

    let config: SpeakingGameConfig
    private(set) var index = 0
    private(set) var phase: Phase = .intro
    private(set) var mode: Mode = .grownUpOnly
    private(set) var lit = 0
    private(set) var onsetMs: Int?
    private(set) var wordCheck: WordCheck = .unavailable
    private(set) var noiseFloorDB: Float?
    private(set) var thresholdDB: Float?
    var grownUpMark: GrownUpMark?

    @ObservationIgnored private var store: ObservationStore?
    @ObservationIgnored private var engine: ListeningEngine?
    @ObservationIgnored private var listeningAllowed = false
    @ObservationIgnored private var trial: ReadAloudTrial?
    @ObservationIgnored private var isActive = true
    @ObservationIgnored private var listenedThisItem = false
    @ObservationIgnored private var replays = 0
    @ObservationIgnored private var lastAdvance: ContinuousClock.Instant?
    /// Bumped for every new item or replay, so a late result from an old one is ignored.
    @ObservationIgnored private var token = 0
    private let speech = SpeechChecker()
    private let speaker = Speaker.shared

    init(config: SpeakingGameConfig) {
        self.config = config
    }

    var item: SpeakItem { config.items[index] }

    var talkState: TalkState {
        switch phase {
        case .pipSpeaking: .listenToPip
        case .getReady: .getReady
        case .speakNow: .speakNow
        case .hearing: .hearing
        case .thinking: .thinking
        default: .off
        }
    }

    var showsWord: Bool {
        switch phase {
        case .speakNow, .hearing, .thinking, .result, .askGrownUp: true
        default: false
        }
    }

    var isWaitingForNext: Bool {
        switch phase {
        case .result, .askGrownUp: true
        default: false
        }
    }

    var canReplay: Bool {
        switch phase {
        case .getReady, .speakNow, .askGrownUp: item.prompt != nil
        default: false
        }
    }

    var bubble: String {
        switch phase {
        case .pipSpeaking: "Listen…"
        case .getReady: "Wait for the green light…"
        case .speakNow:
            if config.activity == .echoCave { "What's left without the first sound?" }
            else if item.tag == .madeUp { "Read my friend's name!" }
            else { "Read this word to me." }
        case .hearing: "I hear you!"
        case .thinking: "Hmm, let me think…"
        case .result: item.isPractice ? "Nice practicing!" : "You lit a firefly!"
        case .askGrownUp(.noVoiceHeard): "I didn't hear anything that time. That's okay!"
        case .askGrownUp(.listeningOff):
            config.activity == .echoCave ? "Say your answer out loud!" : "Read it out loud for your grown-up!"
        default: ""
        }
    }

    var checkTitle: String {
        if case .askGrownUp = phase { return "Grown-up: how did it go?" }
        if item.tag == .madeUp { return "Grown-up: did they read the name?" }
        return "Grown-up check (optional)"
    }

    var checkDetail: String? {
        var parts: [String] = []
        if config.activity == .echoCave { parts.append("The answer is “\(item.target)”.") }
        if item.tag == .madeUp {
            parts.append("Pip can't check made-up words, so your tap is the answer.")
        } else if phase == .result {
            parts.append("Pip: \(wordCheck.pipSummary).")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    func attach(store: ObservationStore, engine: ListeningEngine, listeningAllowed: Bool) {
        self.store = store
        self.engine = engine
        self.listeningAllowed = listeningAllowed
        isActive = true
        chooseMode()
    }

    func introduce() async {
        await speaker.say(config.intro)
    }

    func start() {
        guard phase == .intro else { return }
        speaker.stop()
        chooseMode()
        present()
    }

    /// Echo Cave: Pip says the puzzle again. Listening pauses so the microphone doesn't hear Pip.
    func replayPrompt() {
        guard canReplay else { return }
        replays += 1
        trial?.cancel()
        engine?.stop()
        present()
    }

    func next() {
        // Ignore a double tap, so an item is never recorded twice or skipped unseen.
        guard isWaitingForNext else { return }
        if let lastAdvance, ContinuousClock.now - lastAdvance < .milliseconds(700) { return }
        lastAdvance = .now
        let wasPractice = item.isPractice
        if !wasPractice { record() }
        lit += 1
        replays = 0
        if index + 1 < config.items.count {
            index += 1
            present(preface: wasPractice && !item.isPractice ? PipLines.echoCaveRealStart : nil)
        } else {
            engine?.stop()
            phase = .finished
            Task { await speaker.say(config.doneLine) }
        }
    }

    func leave() {
        isActive = false
        token += 1
        trial?.cancel()
        speech.cancel()
        engine?.stop()
        speaker.stop()
    }

    private func chooseMode() {
        if !listeningAllowed || !ListeningEngine.hasMicPermission {
            mode = .grownUpOnly
        } else {
            mode = speech.isOnDeviceAvailable ? .voiceAndWordCheck : .voiceOnly
        }
    }

    private func present(preface: String? = nil) {
        token += 1
        let current = token
        onsetMs = nil
        wordCheck = .unavailable
        grownUpMark = nil
        noiseFloorDB = nil
        thresholdDB = nil
        // Leave the "waiting for Next" state right away, so a second tap can't act on this item.
        phase = item.prompt != nil || preface != nil ? .pipSpeaking : .getReady
        Task { await runItem(current, preface: preface) }
    }

    private func runItem(_ current: Int, preface: String? = nil) async {
        if let preface {
            phase = .pipSpeaking
            await speaker.say(preface)
            guard isActive, current == token else { return }
        }
        if let prompt = item.prompt {
            phase = .pipSpeaking
            await speaker.say(prompt, essential: true)
            guard isActive, current == token else { return }
        }

        guard mode != .grownUpOnly, let engine, startListening(engine) else {
            // Listening is off, or the microphone couldn't start for this item (say, right after a phone call).
            // A grown-up records this one. The next item tries the microphone again.
            listenedThisItem = false
            phase = .askGrownUp(.listeningOff)
            return
        }

        listenedThisItem = true
        phase = .getReady
        let useRecognizer = mode == .voiceAndWordCheck && item.checkWithRecognizer
        let trial = ReadAloudTrial(engine: engine, speech: useRecognizer ? speech : nil)
        self.trial = trial
        let item = self.item
        let outcome = await trial.run(word: item.target, alsoAccept: item.alsoAccept) { [weak self] progress in
            self?.show(progress, for: current)
        }
        // The microphone is off between items: on only from amber to the answer.
        engine.stop()
        guard isActive, current == token else { return }
        onsetMs = outcome.onsetMs
        wordCheck = outcome.wordCheck
        phase = outcome.wordCheck == .noResponse ? .askGrownUp(.noVoiceHeard) : .result
        if item.isPractice {
            // Practice: Pip says the answer, so the child learns how the puzzle works.
            await speaker.say(PipLines.echoCavePracticeAnswer(item.spoken, item.target), essential: true)
        }
    }

    private func startListening(_ engine: ListeningEngine) -> Bool {
        if engine.isListening { return true }
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func show(_ progress: ReadAloudTrial.Progress, for current: Int) {
        guard current == token else { return }
        switch progress {
        case .speakNow(let floor, let threshold):
            noiseFloorDB = floor
            thresholdDB = threshold
            phase = .speakNow
        case .voiceStarted(let ms):
            onsetMs = ms
            phase = .hearing
        case .voiceEnded:
            phase = .thinking
        }
    }

    private func record() {
        guard let store else { return }
        var observation = ItemObservation(sessionID: store.sessionID, activity: config.activity, itemID: item.id, target: item.target)
        observation.itemTag = item.tag.rawValue
        observation.onsetMs = onsetMs
        observation.wordCheck = listenedThisItem && item.checkWithRecognizer ? wordCheck : .unavailable
        if case .askGrownUp(.noVoiceHeard) = phase { observation.wordCheck = .noResponse }
        observation.grownUpMark = grownUpMark
        observation.timing = listenedThisItem ? .voice : nil
        observation.replays = replays
        store.add(observation)
    }
}

extension WordCheck {
    /// Wording for the grown-up line under each word. Neutral on purpose.
    var pipSummary: String {
        switch self {
        case .matched: "heard the word"
        case .unclear: "not sure"
        case .unavailable: "word check off"
        case .noResponse: "didn't hear a voice"
        }
    }
}
