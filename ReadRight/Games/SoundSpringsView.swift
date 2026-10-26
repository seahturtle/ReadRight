import SwiftUI

/// Sound Springs: Pip says a word, and the child taps the letter it starts with.
///
/// Observes: first-try match, which wrong letter was picked first (mirror-image or sound-alike),
/// time to the first tap (from the moment Pip finishes saying the word), hints, and replays.
struct SoundSpringsView: View {
    @Environment(ObservationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var model = SoundSpringsModel()

    var body: some View {
        GameScaffold(activity: .soundSprings, step: model.lit, total: model.items.count) {
            switch model.phase {
            case .intro:
                PipSays("Hi, I'm Pip! Listen to the word, then tap the letter it starts with.")
                Button("Start") { Task { await model.start() } }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 24))

            case .speaking, .choosing, .celebrating:
                PipSays(model.bubble, mood: model.phase == .celebrating ? .happy : .calm)
                HStack(spacing: 16) {
                    Image(systemName: model.item.picture)
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(Theme.earth)
                        .frame(width: 88, height: 88)
                        .background(Circle().fill(Theme.sky2).overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.line)))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Which letter does it start with?")
                            .themed(.display, 22)
                            .foregroundStyle(Theme.ink)
                        Button {
                            Task { await model.replay() }
                        } label: {
                            Label("Hear it again", systemImage: "speaker.wave.2.fill")
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Theme.panel, radius: 14, drop: 4, size: 16))
                        .disabled(model.phase != .choosing)
                    }
                }
                HStack(spacing: 12) {
                    ForEach(model.choices, id: \.self) { letter in
                        Button(letter) { Task { await model.tap(letter) } }
                            .buttonStyle(ChoiceStyle(look: model.look(for: letter)))
                            .modifier(Wobble(shakes: CGFloat(model.wobbles[letter] ?? 0)))
                            .disabled(model.phase != .choosing || model.tried.contains(letter))
                            .accessibilityLabel("Letter \(letter)")
                    }
                }
                .animation(.easeInOut(duration: 0.45), value: model.wobbles)

            case .finished:
                PipSays("Sound Springs visited! You lit \(model.items.count) fireflies on the way. Every one counts.", mood: .happy)
                Button("Back to the map") { dismiss() }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 22))
            }
        }
        .onAppear { model.attach(store: store) }
        .task {
            if AppFlags.autostart { await model.start() } else { await model.introduce() }
        }
        .onDisappear { model.leave() }
    }
}

@MainActor
@Observable
final class SoundSpringsModel {
    enum Phase: Equatable {
        case intro, speaking, choosing, celebrating, finished
    }

    let items = ItemBank.soundSprings
    private(set) var index = 0
    private(set) var phase: Phase = .intro
    private(set) var choices: [String] = []
    private(set) var wobbles: [String: Int] = [:]
    private(set) var tried: Set<String> = []
    private(set) var hintLetter: String?
    private(set) var correctLetter: String?
    private(set) var lit = 0
    private(set) var bubble = ""

    @ObservationIgnored private var store: ObservationStore?
    @ObservationIgnored private var tries = 0
    @ObservationIgnored private var firstWrong: String?
    @ObservationIgnored private var replays = 0
    @ObservationIgnored private var promptEnded: ContinuousClock.Instant?
    @ObservationIgnored private var firstTapMs: Int?
    @ObservationIgnored private var isActive = true
    private let speaker = Speaker.shared
    private let clock = ContinuousClock()

    private static let cheers = ["Hop! You lit a firefly.", "Nice listening. Off we go!", "You did it. Another firefly!", "Lovely thinking. Hop on!"]
    private static let wobbleLines = ["Almost! Let's listen again.", "That stone wobbled. Try another one.", "Good try. Have another look."]

    var item: LetterItem { items[index] }

    func look(for letter: String) -> ChoiceStyle.Look {
        if correctLetter == letter { return .correct }
        if hintLetter == letter { return .hint }
        if tried.contains(letter) { return .tried }
        return .normal
    }

    func attach(store: ObservationStore) {
        self.store = store
        isActive = true
    }

    func introduce() async {
        await speaker.say("Hi, I'm Pip! Listen to the word, then tap the letter it starts with.")
    }

    func start() async {
        guard phase == .intro else { return }
        await present()
    }

    func replay() async {
        guard phase == .choosing else { return }
        replays += 1
        await speaker.say(item.word, essential: true)
    }

    func tap(_ letter: String) async {
        guard phase == .choosing, !tried.contains(letter) else { return }
        tries += 1
        if firstTapMs == nil, let promptEnded {
            firstTapMs = (clock.now - promptEnded).milliseconds
        }

        if letter == item.answer {
            record()
            correctLetter = letter
            phase = .celebrating
            bubble = Self.cheers[index % Self.cheers.count]
            await speaker.say(bubble)
            try? await Task.sleep(for: .milliseconds(300))
            guard isActive else { return }
            lit += 1
            try? await Task.sleep(for: .milliseconds(650))
            guard isActive else { return }
            await advance()
        } else {
            if firstWrong == nil { firstWrong = letter }
            tried.insert(letter)
            wobbles[letter, default: 0] += 1
            if tries >= 2, hintLetter == nil {
                hintLetter = item.answer
                bubble = "Here's a hint. This stone is glowing. Tap it to hop."
                await speaker.say("\(item.word) starts with \(item.answer).")
            } else {
                bubble = Self.wobbleLines[(index + tries) % Self.wobbleLines.count]
                await speaker.say(bubble)
            }
        }
    }

    func leave() {
        isActive = false
        speaker.stop()
    }

    private func present() async {
        tries = 0
        firstWrong = nil
        replays = 0
        firstTapMs = nil
        promptEnded = nil
        hintLetter = nil
        correctLetter = nil
        tried = []
        wobbles = [:]
        choices = item.choices.shuffled()
        bubble = "Listen…"
        phase = .speaking
        await speaker.say(item.word, essential: true)
        guard isActive else { return }
        // Timing starts when Pip finishes saying the word, not when the screen appears.
        promptEnded = clock.now
        // The word is never written on screen. Seeing it would show the first letter.
        bubble = "Tap the stone with its first letter."
        phase = .choosing
    }

    private func advance() async {
        if index + 1 < items.count {
            index += 1
            await present()
        } else {
            phase = .finished
            await speaker.say("Sound Springs visited! Every firefly counts.")
        }
    }

    private func record() {
        guard let store else { return }
        var observation = ItemObservation(sessionID: store.sessionID, activity: .soundSprings, itemID: item.id, target: item.word)
        observation.firstTry = tries == 1
        observation.tries = tries
        observation.responseMs = firstTapMs
        observation.distractorChosen = firstWrong
        observation.distractorKind = firstWrong.flatMap { item.kind(of: $0)?.rawValue }
        observation.hintShown = hintLetter != nil
        observation.replays = replays
        store.add(observation)
    }
}
