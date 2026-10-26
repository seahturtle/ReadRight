import SwiftUI

/// Firefly Dash: rapid naming. The child says the color of each firefly in a 5×4 grid, as fast as they can.
///
/// Observes: time from the grid appearing (green light) to the first color spoken, total naming time
/// (first voice → last voice), and a grown-up's answer to "did they name them all?"
/// Without listening, a grown-up times it with Go and "I'm done" instead.
struct FireflyDashView: View {
    @Environment(ObservationStore.self) private var store
    @Environment(ListeningEngine.self) private var engine
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showListeningDetails") private var showDetails = false
    @State private var model = FireflyDashModel()

    var body: some View {
        GameScaffold(activity: .fireflyDash, listening: engine.isListening) {
            switch model.phase {
            case .intro:
                PipSays(PipLines.fireflyIntro(profiles.profile.ageBand))
                Button("Practice first") { Task { await model.practice() } }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 22))

            case .practice:
                PipSays("Say these out loud. Start at the arrow and go this way.")
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    FireflyRow(items: model.practiceItems)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.background))
                Button("I'm ready") { Task { await model.getReady() } }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.sun, size: 22))

            case .ready:
                PipSays("Tap Go. When the light turns green, all my fireflies come out. Say every one, row by row, then tap I'm done!")
                Button("Go!") { model.go(listeningAllowed: profiles.profile.listenToReading) }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 26))

            case .gettingReady, .naming:
                TalkLight(
                    state: model.talkState,
                    levelDB: engine.levelDB,
                    speakNowText: "Go! Say them all.",
                    offText: "Grown-up timer is running."
                )
                if model.phase == .naming {
                    FireflyGrid(items: model.grid, columns: ItemBank.fireflyColumns)
                    Button("I'm done") { model.done() }
                        .buttonStyle(ChunkyButtonStyle(fill: Theme.sun, size: 22))
                } else {
                    // Same size as the grid, so nothing jumps when it appears.
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.background)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.ink, style: StrokeStyle(lineWidth: 4, dash: [10, 7])))
                        .frame(height: 300)
                        .overlay(Text("Get ready…").themed(.display, 24).foregroundStyle(Theme.muted))
                }

            case .grownUpCheck:
                PipSays("Wow, you named my fireflies!", mood: .happy)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Grown-up: did they name all 20?")
                        .themed(.display, 18)
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 8) {
                        answer(.all, "All 20")
                        answer(.most, "Most")
                        answer(.few, "A few")
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.soft))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.ink, lineWidth: Theme.line))

            case .finished:
                PipSays("Firefly Dash visited! All my fireflies are glowing. Thank you!", mood: .happy)
                Button("Back to the map") { dismiss() }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 22))
            }

            if showDetails, model.phase == .naming || model.phase == .grownUpCheck {
                ListeningDetails(
                    levelDB: engine.levelDB,
                    floorDB: model.noiseFloorDB,
                    thresholdDB: model.thresholdDB,
                    onsetMs: model.onsetMs,
                    note: model.namingMs.map { "named in \($0) ms" }
                )
            }
        }
        .onAppear { model.attach(store: store, engine: engine, age: profiles.profile.ageBand) }
        .task {
            if AppFlags.autostart { model.go(listeningAllowed: profiles.profile.listenToReading) } else { await model.introduce() }
        }
        .onDisappear { model.leave() }
    }

    private func answer(_ value: NamedAll, _ label: String) -> some View {
        Button(label) { Task { await model.grownUpAnswered(value) } }
            .buttonStyle(ChunkyButtonStyle(fill: Theme.sun, radius: 14, drop: 4, size: 17))
    }
}

@MainActor
@Observable
final class FireflyDashModel {
    enum Phase: Equatable {
        case intro, practice, ready, gettingReady, naming, grownUpCheck, finished
    }

    enum Mode: Equatable {
        case voice, grownUpTimer
    }

    private(set) var grid = ItemBank.fireflyGrid(for: .fiveToSix)
    private(set) var practiceItems = ItemBank.fireflyPractice(for: .fiveToSix)
    @ObservationIgnored private var age = Profile.AgeBand.fiveToSix
    private(set) var phase: Phase = .intro
    private(set) var mode: Mode = .grownUpTimer
    private(set) var onsetMs: Int?
    private(set) var namingMs: Int?
    private(set) var noiseFloorDB: Float?
    private(set) var thresholdDB: Float?
    private(set) var heardVoice = false

    @ObservationIgnored private var store: ObservationStore?
    @ObservationIgnored private var engine: ListeningEngine?
    @ObservationIgnored private var detector = VoiceOnsetDetector(settings: .rapidNaming)
    @ObservationIgnored private var revealedAt: TimeInterval?
    @ObservationIgnored private var goPressed: ContinuousClock.Instant?
    @ObservationIgnored private var capTask: Task<Void, Never>?
    @ObservationIgnored private var revealTask: Task<Void, Never>?
    @ObservationIgnored private var isActive = true
    private let speaker = Speaker.shared
    private let clock = ContinuousClock()

    /// Stop after this long even if nobody taps "I'm done".
    private let maximumSeconds = 90

    var talkState: TalkState {
        switch phase {
        case .gettingReady: .getReady
        case .naming: mode == .voice ? (heardVoice ? .hearing : .speakNow) : .off
        default: .off
        }
    }

    func attach(store: ObservationStore, engine: ListeningEngine, age: Profile.AgeBand) {
        self.store = store
        self.engine = engine
        self.age = age
        grid = ItemBank.fireflyGrid(for: age)
        practiceItems = ItemBank.fireflyPractice(for: age)
        isActive = true
    }

    func introduce() async {
        await speaker.say(PipLines.fireflyIntro(age))
    }

    func practice() async {
        guard phase == .intro else { return }
        phase = .practice
        await speaker.say(PipLines.fireflyPractice)
    }

    func getReady() async {
        guard phase == .practice else { return }
        phase = .ready
        await speaker.say(PipLines.fireflyReady)
    }

    func go(listeningAllowed: Bool) {
        // A second tap on Go must not restart the timing. (`.intro` is allowed for the -autostart flag.)
        guard phase == .ready || phase == .intro else { return }
        speaker.stop()
        mode = .grownUpTimer
        if listeningAllowed, let engine, ListeningEngine.hasMicPermission {
            do {
                if !engine.isListening { try engine.start() }
                mode = .voice
            } catch {
                mode = .grownUpTimer
            }
        }
        detector = VoiceOnsetDetector(settings: .rapidNaming)
        detector.listenFrom = .infinity
        revealedAt = nil
        onsetMs = nil
        namingMs = nil
        heardVoice = false

        if mode == .voice {
            // Amber first: the microphone learns the room's quiet before the grid appears.
            phase = .gettingReady
            engine?.markStimulus { [weak self] time, level in
                self?.handle(time: time, level: level)
            }
            let fallback = VoiceOnsetDetector.Settings.rapidNaming.calibrationDuration + 1.2
            revealTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(fallback))
                guard !Task.isCancelled else { return }
                self?.reveal()
            }
        } else {
            reveal()
        }
    }

    /// The child (or a grown-up) tapped "I'm done", or time ran out.
    func done() {
        guard phase == .naming else { return }
        if mode == .voice {
            finishNaming(onset: detector.onsetTime, lastVoice: detector.lastVoiceTime)
        } else {
            namingMs = goPressed.map { (clock.now - $0).milliseconds }
            finishNaming(onset: nil, lastVoice: nil)
        }
    }

    func grownUpAnswered(_ answer: NamedAll) async {
        // Change the phase before saving, so a double tap can't save twice.
        guard phase == .grownUpCheck else { return }
        phase = .finished
        record(answer)
        await speaker.say(PipLines.fireflyDone)
    }

    func leave() {
        isActive = false
        capTask?.cancel()
        revealTask?.cancel()
        engine?.stop()
        speaker.stop()
    }

    /// Green light: the grid appears and timing starts.
    private func reveal() {
        // Runs once: from the amber light in voice mode, or straight from Go with the grown-up timer.
        guard phase == .gettingReady || (mode == .grownUpTimer && phase != .naming) else { return }
        revealTask?.cancel()
        if mode == .voice, let engine {
            let now = engine.secondsSinceStimulus()
            revealedAt = now
            detector.listenFrom = now
            noiseFloorDB = detector.noiseFloorDB
            thresholdDB = detector.thresholdDB
        }
        goPressed = clock.now
        phase = .naming
        let limit = maximumSeconds
        capTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(limit))
            guard !Task.isCancelled else { return }
            self?.done()
        }
    }

    private func handle(time: TimeInterval, level: Float) {
        guard phase == .gettingReady || phase == .naming else { return }
        for event in detector.process(time: time, levelDB: level) {
            switch event {
            case .calibrated:
                reveal()
            case .onset(let at):
                heardVoice = true
                onsetMs = Int(((at - (revealedAt ?? at)) * 1000).rounded())
            case .finished:
                // A child who is stuck may pause for a while. Ending the dash then would make them look
                // faster than they were, so only "I'm done" or the time limit ends it.
                break
            }
        }
    }

    private func finishNaming(onset: TimeInterval?, lastVoice: TimeInterval?) {
        guard phase == .naming else { return }
        capTask?.cancel()
        if let onset, let lastVoice {
            onsetMs = Int(((onset - (revealedAt ?? onset)) * 1000).rounded())
            namingMs = Int(((lastVoice - onset) * 1000).rounded())
        }
        engine?.clearStimulus()
        engine?.stop()
        phase = .grownUpCheck
    }

    private func record(_ answer: NamedAll) {
        guard let store else { return }
        var observation = ItemObservation(sessionID: store.sessionID, activity: .fireflyDash, itemID: age == .fiveToSix ? "fd-pictures" : "fd-letters", target: age == .fiveToSix ? "20 pictures" : "20 letters")
        observation.onsetMs = mode == .voice ? onsetMs : nil
        observation.namingMs = namingMs
        observation.namedAll = answer
        observation.timing = mode == .voice ? .voice : .grownUpTaps
        store.add(observation)
    }
}

/// A firefly carrying a picture (ages 5–6) or a letter (ages 7–8).
/// Every firefly is the same color, so color never matters, which is fair to color-blind children.
struct FireflyDot: View {
    let item: NamingItem
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            HStack(spacing: size * 0.05) {
                Ellipse().fill(Color.white).overlay(Ellipse().strokeBorder(Theme.ink.opacity(0.6), lineWidth: 1.5)).frame(width: size * 0.34, height: size * 0.24)
                Ellipse().fill(Color.white).overlay(Ellipse().strokeBorder(Theme.ink.opacity(0.6), lineWidth: 1.5)).frame(width: size * 0.34, height: size * 0.24)
            }
            .offset(y: -size * 0.32)
            Circle()
                .fill(Color(hex: 0xFFF1C4))
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2.5))
                .frame(width: size * 0.78, height: size * 0.78)
                .shadow(color: Theme.sun.opacity(0.7), radius: size * 0.12)
            if let symbol = item.symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(Theme.ink)
            } else {
                Text(item.rawValue)
                    .themed(.reading, size * 0.46)
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(item.isLetter ? "letter \(item.rawValue)" : item.rawValue)
    }
}

struct FireflyRow: View {
    let items: [NamingItem]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                FireflyDot(item: items[index], size: 48)
            }
        }
    }
}

struct FireflyGrid: View {
    let items: [NamingItem]
    let columns: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 12) {
            ForEach(items.indices, id: \.self) { index in
                FireflyDot(item: items[index], size: 56)
            }
        }
        .padding(14)
        .frame(minHeight: 300)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: 0xD9F5E9)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.mintDark, lineWidth: 5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Twenty fireflies in four rows")
    }
}
