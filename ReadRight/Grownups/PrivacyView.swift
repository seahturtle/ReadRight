import SwiftUI

/// How ReadRight handles data, in plain language for parents, with a short version to read with a child.
/// Every promise here matches what the code does. If you change how data is stored or used, change this page too.
struct PrivacyView: View {
    /// Setup shows this page before anything is saved, so it hides the live choices there.
    var showsChoices = true

    @Environment(ProfileStore.self) private var profiles

    private struct Row: Identifiable {
        let id = UUID()
        let what: String
        let why: String
        let lives: String
    }

    private let rows: [Row] = [
        Row(what: "Nickname and age group", why: "Greet your child and pick words that fit their age", lives: "This iPhone only"),
        Row(what: "Taps, response times and which letters were picked", why: "Build the family summary", lives: "This iPhone only, if the notebook is on"),
        Row(what: "When a voice started and stopped, and whether a word was heard (yes or unclear)", why: "Time reading and check answers", lives: "This iPhone only, if the notebook is on"),
        Row(what: "Your Grown-up check marks and optional background answers", why: "Add context to the summary", lives: "This iPhone only"),
        Row(what: "Your child's voice", why: "Measured for timing and the word check, then thrown away right away", lives: "Never saved anywhere"),
        Row(what: "Pip's voice recordings (made by a grown-up in the Voice Studio)", why: "Play a real voice instead of the iPhone's", lives: "This iPhone, in the Files app → ReadRight"),
        Row(what: "Photos, location, contacts, real names, advertising ID", why: "Not collected", lives: "Nowhere"),
    ]

    var body: some View {
        @Bindable var editableProfiles = profiles
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "For kids, read together")
                    Text("Pip keeps a tiny notebook").themed(.display, 22).foregroundStyle(Theme.ink)
                    Text("Pip writes down how the game went, like which stones you tapped and how long you thought. Pip only listens when the light is green and the ear is glowing, and Pip never keeps your voice. The notebook stays on this iPhone. Only your grown-up decides if anyone else sees it, and they can erase it any time.")
                        .themed(.body, 16)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.soft))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.ink, lineWidth: Theme.line))

                section("The short version", [
                    "ReadRight never sends anything over the internet. It has no accounts, no servers, no ads and no analytics.",
                    "Nothing leaves this iPhone unless you tap Share on a summary and choose where it goes.",
                    "Your child's voice is never recorded or saved.",
                    "Everything starts off. You choose whether to keep the notebook and whether Pip listens.",
                ])

                VStack(alignment: .leading, spacing: 8) {
                    Text("What's collected, and where it lives").themed(.display, 18).foregroundStyle(Theme.ink)
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.what).themed(.display, 15).foregroundStyle(Theme.ink)
                            Text("Why: \(row.why)").themed(.body, 14).foregroundStyle(Theme.inkSoft)
                            Text("Where: \(row.lives)").themed(.body, 14).foregroundStyle(Theme.inkSoft)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 1) }
                    }
                }

                section("Listening and speech recognition", [
                    "The microphone is on only during a listening round (Echo Cave, Word Woods, Firefly Dash, or the Listening Lab), shown by the glowing ear and the traffic light. It turns off between words and when the app goes to the background.",
                    "Speech recognition runs only on this iPhone, using Apple's on-device recognizer. If this iPhone can't recognize speech on its own, the word check turns off and only timing is used. Audio is never sent to a server.",
                    "iOS asks your permission before ReadRight can use the microphone. You can turn it off any time in the Settings app → ReadRight.",
                ])

                section("Keeping it safe", [
                    "Play notes are stored in one file on this iPhone. It's encrypted whenever the phone is locked and isn't included in iCloud backups.",
                    "Notes older than 90 days are deleted automatically.",
                    "Grown-ups → Settings → Erase everything deletes all play notes, the nickname, background answers and choices right away.",
                    "The grown-up gate (a times-table question) keeps young children out of the summary and settings. It's a speed bump, not a password.",
                ])

                section("Why voice gets extra care", [
                    "The U.S. Federal Trade Commission treats a recording of a child's voice as personal information under its children's privacy rule (COPPA). That's why ReadRight never records or keeps your child's voice and processes sound only on this iPhone, in the moment. This is a design note, not legal advice.",
                ])

                section("About the results", [
                    "ReadRight is a preliminary screener for early signs of dyslexia and other reading and listening difficulties. Based on your child's results, it recommends when to see a doctor or specialist, who can do a full evaluation and diagnosis.",
                ])

                if showsChoices {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your choices").themed(.display, 18).foregroundStyle(Theme.ink)
                        ChoicesEditor(profile: $editableProfiles.profile)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(ScreenBackground())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).themed(.display, 18).foregroundStyle(Theme.ink)
            bulletList(items)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
