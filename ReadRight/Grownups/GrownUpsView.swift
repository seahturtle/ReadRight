import AVFoundation
import SwiftUI

/// The grown-up area, with tabs like the team's prototype: the family summary, what each activity
/// observes, the research behind it, and settings.
struct GrownUpsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case activities = "Activities"
        case research = "Research"
        case settings = "Settings"

        var id: String { rawValue }
    }

    @State private var tab: Tab = .summary

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // TODO(team): show ParentGateView before this screen (see ParentGateView.swift).
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Grown-up area")
                        Text("Summary, research and settings").themed(.display, 26).foregroundStyle(Theme.ink)
                        Text("Everything here describes what happened during play. It's information to talk about, not a result. Only a qualified professional can assess reading difficulties, including dyslexia.")
                            .themed(.body, 15)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Picker("Section", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Group {
                        switch tab {
                        case .summary: SummaryView()
                        case .activities: ActivitiesExplainerView()
                        case .research: EvidenceView()
                        case .settings: GrownUpSettingsView()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .chunky(radius: 20, drop: 4)
                }
                .padding(16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Grown-ups")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Settings for grown-ups: choices, background, Pip's voice, comfort, testing tools, and erase.
struct GrownUpSettingsView: View {
    @Environment(ObservationStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(Comfort.self) private var comfort
    @AppStorage(PipVoice.defaultsKey) private var chosenVoice = ""
    @Environment(ListeningEngine.self) private var engine
    @AppStorage("showListeningDetails") private var showListeningDetails = false
    @State private var confirmingErase = false

    var body: some View {
        @Bindable var profiles = profiles
        VStack(alignment: .leading, spacing: 18) {
            Text("Your choices").themed(.display, 20).foregroundStyle(Theme.ink)
            ChoicesEditor(profile: $profiles.profile)

            Text("Background (optional)").themed(.display, 20).foregroundStyle(Theme.ink)
            BackgroundEditor(profile: $profiles.profile)

            Text("Pip and comfort").themed(.display, 20).foregroundStyle(Theme.ink)
            NavigationLink(value: Route.pipVoice) { settingsRow("Pip's voice", systemImage: "person.wave.2") }
            ComfortToggles()

            Text("Testing tools").themed(.display, 20).foregroundStyle(Theme.ink)
            NavigationLink(value: Route.listeningLab) { settingsRow("Listening Lab", systemImage: "waveform") }
            NavigationLink(value: Route.observationLog) { settingsRow("Raw observations", systemImage: "list.bullet.rectangle") }
            Toggle(isOn: $showListeningDetails) {
                Text("Show listening numbers during games").themed(.body, 16)
            }
            .tint(Theme.mint)

            Text("Privacy").themed(.display, 20).foregroundStyle(Theme.ink)
            NavigationLink(value: Route.privacy) { settingsRow("How ReadRight handles data", systemImage: "lock.shield") }
            Button("Erase everything on this iPhone") { confirmingErase = true }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.panel, radius: 14, drop: 4, size: 16))
                .confirmationDialog("Erase every observation, the nickname, background and choices?", isPresented: $confirmingErase, titleVisibility: .visible) {
                    Button("Erase everything", role: .destructive) {
                        engine.stop()
                        store.deleteAll()
                        profiles.reset()
                        // Settings go back to how they were on a brand-new install.
                        comfort.largerText = false
                        comfort.calmMotion = false
                        comfort.speakPrompts = true
                        showListeningDetails = false
                        chosenVoice = ""
                    }
                }
        }
        .foregroundStyle(Theme.ink)
    }

    private func settingsRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage).themed(.body, 17)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.background))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ink, lineWidth: 2))
    }
}

/// The three choices from setup. Turning on listening asks iOS for microphone and speech permission.
struct ChoicesEditor: View {
    @Binding var profile: Profile
    @State private var permissionNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ConsentToggle(
                isOn: $profile.keepNotebook,
                title: "Keep Pip's notebook on this iPhone",
                detail: "Saves play notes so you can see the summary later. Off means notes disappear when the app closes."
            )
            ConsentToggle(
                isOn: Binding(
                    get: { profile.listenToReading },
                    set: { newValue in
                        if newValue {
                            Task { await turnOnListening() }
                        } else {
                            profile.listenToReading = false
                        }
                    }
                ),
                title: "Listen while my child reads out loud",
                detail: "Pip uses the microphone to time when your child starts talking, and Apple's speech recognition on this iPhone to check words. Audio is never saved or sent anywhere. Turning this on asks for permission."
            )
            if let permissionNote {
                Text(permissionNote).themed(.body, 14).foregroundStyle(Theme.warnInk)
            }
            ConsentToggle(
                isOn: $profile.allowSharing,
                title: "Let me share the summary",
                detail: "Adds a Share button to the summary, so you can pass it to a teacher or specialist yourself. Nothing is sent unless you choose where."
            )
        }
    }

    private func turnOnListening() async {
        permissionNote = nil
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        _ = await SpeechChecker.requestAuthorization()
        if micAllowed {
            profile.listenToReading = true
        } else {
            profile.listenToReading = false
            permissionNote = "Microphone access is off for ReadRight. To turn it on, open the Settings app → ReadRight → Microphone."
        }
    }
}

struct ConsentToggle: View {
    @Binding var isOn: Bool
    let title: String
    let detail: String

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).themed(.display, 16).foregroundStyle(Theme.ink)
                Text(detail).themed(.body, 14).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.mint)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.background))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: 2))
    }
}

/// Optional questions. Research links family history and early speech delays to reading differences,
/// and vision, hearing and home languages change what the play results mean.
struct BackgroundEditor: View {
    @Binding var profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            question("Has a parent, brother or sister had trouble learning to read?", $profile.familyHistory)
            question("Did your child start talking later than others, or have speech or language help?", $profile.speechDelay)
            question("Have your child's vision and hearing been checked in the last year?", $profile.visionHearingChecked)
            question("Does your child speak another language at home?", $profile.speaksOtherLanguages)
            Text("These answers stay on this iPhone. They add context to the summary and never change how the games work.")
                .themed(.body, 13)
                .foregroundStyle(Theme.muted)
        }
    }

    private func question(_ text: String, _ answer: Binding<Profile.Answer?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).themed(.body, 15).foregroundStyle(Theme.ink)
            Picker(text, selection: answer) {
                Text("Skip").tag(Profile.Answer?.none)
                ForEach(Profile.Answer.allCases, id: \.self) { Text($0.label).tag(Profile.Answer?.some($0)) }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct ComfortToggles: View {
    @Environment(Comfort.self) private var comfort

    var body: some View {
        @Bindable var comfort = comfort
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $comfort.largerText) { Text("Larger text").themed(.body, 16) }
            Toggle(isOn: $comfort.calmMotion) { Text("Calm motion (no hopping or bobbing)").themed(.body, 16) }
            Toggle(isOn: $comfort.speakPrompts) { Text("Pip reads instructions out loud").themed(.body, 16) }
        }
        .tint(Theme.mint)
        .foregroundStyle(Theme.ink)
    }
}

/// The comfort menu from the home screen. Anyone can open it.
struct ComfortSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Comfort settings").themed(.display, 24).foregroundStyle(Theme.ink)
                ComfortToggles()
                Text("Words the games depend on, like the word to match in Sound Springs, are always spoken.")
                    .themed(.body, 14)
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
