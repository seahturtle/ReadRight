import SwiftUI

@main
struct ReadRightApp: App {
    @State private var store = ObservationStore()
    @State private var profiles = ProfileStore()
    @State private var listening = ListeningEngine()
    @State private var comfort = Comfort()

    init() {
        AudioSessionConfigurator.configure()
        Speaker.shared.warmUp()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(profiles)
                .environment(listening)
                .environment(comfort)
        }
    }
}

enum Route: Hashable {
    case soundSprings, echoCave, wordWoods, fireflyDash, grownUps, listeningLab, observationLog, pipVoice, privacy

    init(_ activity: Activity) {
        switch activity {
        case .soundSprings: self = .soundSprings
        case .echoCave: self = .echoCave
        case .wordWoods: self = .wordWoods
        case .fireflyDash: self = .fireflyDash
        }
    }
}

struct RootView: View {
    @Environment(ObservationStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(ListeningEngine.self) private var listening
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route] = AppFlags.startRoutes

    var body: some View {
        Group {
            if profiles.profile.setupDone || AppFlags.skipSetup {
                NavigationStack(path: $path) {
                    LetterwoodMapView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .soundSprings: SoundSpringsView()
                            case .echoCave: EchoCaveView()
                            case .wordWoods: WordWoodsView()
                            case .fireflyDash: FireflyDashView()
                            case .grownUps: GrownUpsView()
                            case .listeningLab: ListeningLabView()
                            case .observationLog: ObservationLogView()
                            case .pipVoice: PipVoiceView()
                            case .privacy: PrivacyView()
                            }
                        }
                }
            } else {
                WelcomeView()
            }
        }
        .tint(Theme.earth)
        // The prototype's bright daytime look, on every screen.
        .preferredColorScheme(.light)
        .onAppear {
            store.savesToDisk = profiles.profile.keepNotebook
            AudioSessionConfigurator.listeningChosen = profiles.profile.listenToReading
            AudioSessionConfigurator.configure()
        }
        .onChange(of: profiles.profile.keepNotebook) { _, keep in
            store.savesToDisk = keep
            // Only a grown-up turning the notebook off deletes the saved file.
            if !keep { store.forgetSavedFile() }
        }
        .onChange(of: profiles.profile.listenToReading) { _, chosen in
            if !chosen { listening.stop() }
            AudioSessionConfigurator.listeningChosen = chosen
            AudioSessionConfigurator.configure()
        }
        .onChange(of: profiles.profile.setupDone) { _, _ in
            path = []
        }
        .onChange(of: scenePhase) { _, phase in
            // The microphone is never on in the background. (Pulling down Control Center only makes the
            // app "inactive" for a moment, so that doesn't stop a word mid-read.)
            if phase == .background { listening.stop() }
        }
    }
}

/// Launch arguments for testing and screenshots. Set them in Xcode under Product → Scheme → Edit Scheme → Arguments.
enum AppFlags {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// `-silent`: Pip doesn't speak out loud.
    static var silent: Bool { arguments.contains("-silent") }

    /// `-autostart`: skip a game's intro and start playing right away (for screenshots).
    static var autostart: Bool { arguments.contains("-autostart") }

    /// `-skipSetup`: go straight to the map (for screenshots).
    static var skipSetup: Bool { arguments.contains("-skipSetup") }

    /// `-sampleSummary`: show the family summary layout example (made-up values, clearly labeled).
    static var sampleSummary: Bool { arguments.contains("-sampleSummary") }

    /// `-screen wordWoods`: open straight to a screen.
    /// Values: soundSprings, echoCave, wordWoods, fireflyDash, grownUps, lab, log, voice.
    static var startRoutes: [Route] {
        guard let flag = arguments.firstIndex(of: "-screen"), flag + 1 < arguments.count else { return [] }
        switch arguments[flag + 1] {
        case "soundSprings": return [.soundSprings]
        case "echoCave": return [.echoCave]
        case "wordWoods": return [.wordWoods]
        case "fireflyDash": return [.fireflyDash]
        case "grownUps": return [.grownUps]
        case "lab": return [.grownUps, .listeningLab]
        case "log": return [.grownUps, .observationLog]
        case "voice": return [.grownUps, .pipVoice]
        default: return []
        }
    }
}
