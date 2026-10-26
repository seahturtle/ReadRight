import SwiftUI

/// First launch, from the prototype: a welcome for the child, then a short setup card for the grown-up
/// with a nickname, age group, privacy choices and optional background.
struct WelcomeView: View {
    @Environment(ProfileStore.self) private var profiles
    @State private var nickname = ""
    /// Edits stay here until "Start the walk", so nothing is saved before the grown-up agrees.
    @State private var draft = Profile()
    @State private var acknowledged = false
    @State private var showingPrivacy = false

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "For the grown-up · 1 minute")
                            Text("Set up before you play").themed(.display, 24).foregroundStyle(Theme.ink)
                            Text("ReadRight is a preliminary screener for early signs of dyslexia and other reading and listening difficulties. It notices how a child plays, like how long a choice takes, which letters get picked and when a voice starts, and recommends when to see a doctor or specialist. It works best with a grown-up sitting nearby.")
                                .themed(.body, 15)
                                .foregroundStyle(Theme.inkSoft)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("A nickname for your explorer").themed(.display, 16).foregroundStyle(Theme.ink)
                            TextField("Explorer", text: $nickname)
                                .themed(.body, 17)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.background))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: Theme.line))
                                .onChange(of: nickname) { _, value in
                                    if value.count > 16 { nickname = String(value.prefix(16)) }
                                }
                            Text("A made-up name is fine. Please don't use a full name.")
                                .themed(.body, 13)
                                .foregroundStyle(Theme.muted)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Age group").themed(.display, 16).foregroundStyle(Theme.ink)
                            Picker("Age group", selection: $draft.ageBand) {
                                ForEach(Profile.AgeBand.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            Text("Chooses which words and puzzles Pip uses.").themed(.body, 13).foregroundStyle(Theme.muted)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your choices").themed(.display, 16).foregroundStyle(Theme.ink)
                            Text("Everything starts off. You can change these later in Grown-ups → Settings.")
                                .themed(.body, 13)
                                .foregroundStyle(Theme.muted)
                            ChoicesEditor(profile: $draft)
                        }

                        DisclosureGroup {
                            BackgroundEditor(profile: $draft).padding(.top, 8)
                        } label: {
                            Text("A little background (optional)").themed(.display, 16).foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.ink)

                        Toggle(isOn: $acknowledged) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("I'm this child's parent or guardian.").themed(.display, 16).foregroundStyle(Theme.ink)
                                Text("I understand ReadRight is a preliminary screener, and a doctor or specialist makes a full diagnosis.")
                                    .themed(.body, 14)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .tint(Theme.mint)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.background))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: 2))

                        HStack(spacing: 12) {
                            Button("Start the walk") { finish() }
                                .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 22))
                                .disabled(!acknowledged)
                            Button("How data is handled") { showingPrivacy = true }
                                .buttonStyle(ChunkyButtonStyle(fill: Theme.panel, radius: 14, drop: 4, size: 15))
                        }
                    }
                    .padding(18)
                    .chunky(radius: 28)
                }
                .padding(16)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingPrivacy) {
            NavigationStack {
                PrivacyView(showsChoices: false)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { showingPrivacy = false } }
                    }
            }
        }
        .onAppear {
            draft = profiles.profile
            nickname = draft.nickname == "Explorer" ? "" : draft.nickname
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Overlays don't change the layout size, so the big hills can't make the screen wider than the phone.
            LinearGradient(colors: [Theme.sky1, Theme.sky2], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .bottom) {
                    ZStack {
                        Ellipse().fill(Theme.hill1).frame(width: 520, height: 150).offset(x: -60, y: 90)
                        Ellipse().fill(Theme.hill2).frame(width: 420, height: 130).offset(x: 140, y: 100)
                    }
                }
                .overlay(alignment: .bottom) {
                    PipView(mood: .happy, size: 150).padding(.bottom, 24)
                }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 36, bottomLeadingRadius: 36, bottomTrailingRadius: 12, topTrailingRadius: 36))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: 36, bottomLeadingRadius: 36, bottomTrailingRadius: 12, topTrailingRadius: 36).strokeBorder(Theme.ink, lineWidth: 4))

            Eyebrow(text: "A reading adventure, about 8 minutes")
            Text("Walk through Letterwood with Pip").themed(.display, 34).foregroundStyle(Theme.ink)
            Text("Hop across stepping stones while you match sounds, solve sound puzzles, read little words and name pictures. Every try lights a firefly. There are no lives, no timers on screen, and nothing to lose.")
                .themed(.body, 17)
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                Pill(text: "4 islands")
                Pill(text: "Any order")
                Pill(text: "Stop any time")
            }
        }
    }

    private func finish() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.nickname = trimmed.isEmpty ? "Explorer" : trimmed
        draft.setupDone = true
        profiles.profile = draft
    }
}
