import SwiftUI

/// The frame every game screen shares: Pip's path at the top, then the activity in a white stage card.
struct GameScaffold<Content: View>: View {
    let activity: Activity
    var step = 0
    var total = 0
    var listening = false
    let content: Content

    init(activity: Activity, step: Int = 0, total: Int = 0, listening: Bool = false, @ViewBuilder content: () -> Content) {
        self.activity = activity
        self.step = step
        self.total = total
        self.listening = listening
        self.content = content()
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if total > 0 {
                        PathScene(step: step, total: total, listening: listening)
                        StepDots(step: step, total: total)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        content
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .chunky(radius: 28)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(activity.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "Step 3 of 8" with a dot for each step: mint for done, sun for now.
struct StepDots: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("Step \(min(step + 1, total)) of \(total)")
                .themed(.body, 15)
                .foregroundStyle(Theme.inkSoft)
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < step ? Theme.mint : (index == step ? Theme.sun : .clear))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2.5))
                    .frame(width: 14, height: 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(min(step + 1, total)) of \(total)")
    }
}

/// Pip talking, in a speech bubble. The game also speaks the line, so children who can't read yet can follow.
struct PipSays: View {
    let text: String
    var mood: PipView.Mood = .calm

    init(_ text: String, mood: PipView.Mood = .calm) {
        self.text = text
        self.mood = mood
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            PipView(mood: mood, size: 50)
            Text(text)
                .themed(.body, 19)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 48, alignment: .leading)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 18, topTrailingRadius: 18)
                        .fill(Theme.panel)
                        .overlay(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 18, topTrailingRadius: 18).strokeBorder(Theme.ink, lineWidth: Theme.line))
                )
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The traffic light that tells a child when to talk.
enum TalkState: Equatable {
    /// Pip is talking. Listen.
    case listenToPip
    /// Amber: the microphone is learning the room's quiet. Don't talk yet.
    case getReady
    /// Green: talk now.
    case speakNow
    /// Green, pulsing: Pip hears a voice.
    case hearing
    /// Pip is deciding.
    case thinking
    /// The microphone isn't being used.
    case off
}

struct TalkLight: View {
    let state: TalkState
    var levelDB: Float = AudioLevel.minimumDB
    var speakNowText = "Your turn! Say it now."
    var offText = "Read it to your grown-up."

    @Environment(Comfort.self) private var comfort

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color)
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.line))
                    .frame(width: 44, height: 44)
                    .shadow(color: isGreen ? Theme.mint.opacity(0.8) : .clear, radius: isGreen ? 10 : 0)
                    .scaleEffect(pulse)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .animation(comfort.calmMotion ? nil : .easeOut(duration: 0.12), value: pulse)
            Text(text)
                .themed(.display, 20)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .chunky(background, radius: 20, drop: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var isGreen: Bool { state == .speakNow || state == .hearing }

    /// While Pip hears a voice, the light swells with the loudness.
    private var pulse: CGFloat {
        guard state == .hearing, !comfort.calmMotion else { return 1 }
        let loudness = CGFloat(min(max((levelDB + 60) / 40, 0), 1))
        return 1 + loudness * 0.18
    }

    private var color: Color {
        switch state {
        case .listenToPip, .thinking: Theme.soft
        case .getReady: Theme.sun
        case .speakNow, .hearing: Theme.mint
        case .off: Color(hex: 0xD6D6E2)
        }
    }

    private var background: Color {
        switch state {
        case .speakNow, .hearing: Color(hex: 0xD9F5E9)
        case .getReady: Theme.warnBackground
        default: Theme.panel
        }
    }

    private var icon: String {
        switch state {
        case .listenToPip: "ear"
        case .getReady: "hourglass"
        case .speakNow: "mic.fill"
        case .hearing: "waveform"
        case .thinking: "ellipsis"
        case .off: "mic.slash"
        }
    }

    private var text: String {
        switch state {
        case .listenToPip: "Listen to Pip…"
        case .getReady: "Get ready…"
        case .speakNow: speakNowText
        case .hearing: "I hear you!"
        case .thinking: "Pip is thinking…"
        case .off: offText
        }
    }
}

/// A word to read, on a dashed card like the prototype. Its border turns green with the light.
struct WordCard: View {
    let word: String?
    var green = false
    var creature: Int?

    var body: some View {
        VStack(spacing: 6) {
            if let creature {
                CreatureView(index: creature, size: 64)
                Text("This is Pip's friend. Read their name!")
                    .themed(.body, 15)
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(word ?? "• • •")
                .themed(.reading, word == nil ? 44 : 72)
                .tracking(word == nil ? 0 : 6)
                .foregroundStyle(word == nil ? Theme.muted : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(minHeight: 96)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(green ? Color(hex: 0xD9F5E9) : Theme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(green ? Theme.mintDark : Theme.ink, style: StrokeStyle(lineWidth: green ? 5 : 4, dash: green ? [] : [10, 7]))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word.map { "Word: \($0)" } ?? "Get ready")
    }
}

/// A big letter (or picture) choice, like the prototype's stones.
struct ChoiceStyle: ButtonStyle {
    enum Look {
        case normal, tried, correct, hint
    }

    var look: Look = .normal

    func makeBody(configuration: Configuration) -> some View {
        ChoiceBody(configuration: configuration, look: look)
    }

    private struct ChoiceBody: View {
        let configuration: ButtonStyleConfiguration
        let look: Look
        @Environment(Comfort.self) private var comfort
        @State private var glow = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            let pressed = configuration.isPressed
            configuration.label
                .themed(.reading, 56)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 104)
                .background(shape.fill(look == .correct ? Theme.mint : Theme.background).overlay(shape.strokeBorder(Theme.ink, lineWidth: 4)))
                .overlay {
                    if look == .hint {
                        shape.strokeBorder(Theme.sun, lineWidth: glow ? 9 : 4).padding(-6)
                    }
                }
                .offset(y: pressed ? 4 : 0)
                .background(shape.fill(Theme.ink).offset(y: 5))
                .padding(.bottom, 5)
                .opacity(look == .tried ? 0.4 : 1)
                .onAppear { startGlow() }
                .onChange(of: look) { _, _ in startGlow() }
        }

        private func startGlow() {
            guard look == .hint, !comfort.calmMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

/// A gentle side-to-side wobble for a wrong tap. Never a red X.
struct Wobble: GeometryEffect {
    var shakes: CGFloat
    var distance: CGFloat = 8

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: distance * sin(shakes * .pi * 2), y: 0))
    }
}

/// The prototype's "Grown-up check" box. A grown-up's mark overrides the automatic word check.
struct GrownUpCheck: View {
    @Binding var mark: GrownUpMark?
    var title = "Grown-up check (optional)"
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .themed(.display, 17)
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .themed(.body, 15)
                    .foregroundStyle(Theme.inkSoft)
            }
            HStack(spacing: 8) {
                chip(.readIt, "Read it")
                chip(.neededHelp, "Needed help")
                chip(.skipped, "Skipped")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.soft))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.ink, lineWidth: Theme.line))
    }

    private func chip(_ value: GrownUpMark, _ label: String) -> some View {
        Button {
            mark = (mark == value) ? nil : value
        } label: {
            Text(label)
                .themed(.body, 15)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(mark == value ? Theme.sun : Theme.panel))
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mark == value ? .isSelected : [])
    }
}

/// A small grown-up panel that shows the live listening numbers. Turn it on in Grown-ups.
struct ListeningDetails: View {
    let levelDB: Float
    let floorDB: Float?
    let thresholdDB: Float?
    let onsetMs: Int?
    let note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Listening numbers")
            LevelMeter(levelDB: levelDB, floorDB: floorDB, thresholdDB: thresholdDB)
            HStack {
                Text("Voice started: \(onsetMs.map { "\($0) ms after green" } ?? "–")")
                Spacer()
                if let note { Text(note) }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.inkSoft)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.background))
    }
}

extension Duration {
    var milliseconds: Int {
        let (seconds, attoseconds) = components
        return Int((Double(seconds) * 1000 + Double(attoseconds) / 1e15).rounded())
    }
}
