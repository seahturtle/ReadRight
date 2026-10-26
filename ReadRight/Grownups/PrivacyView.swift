import SwiftUI

// TODO(team): Write the privacy screen, in your own words and in plain language for parents.
// Your friend's web prototype has a "Privacy and consent" tab you can use as a starting point
// (a kid version, a "what is collected and where it lives" table, and why voice gets extra care).
// The choices themselves (notebook, listening, sharing) are already in setup and Grown-ups → Settings.
//
// It must cover (see the plan's Security section):
// - What ReadRight measures: tap times, which letters were picked, when a voice started and stopped,
//   and whether the word check "heard the word" (matched / unclear). Nothing else.
// - Audio is never saved. The microphone is on only while the ear glows in Word Woods or Firefly Dash.
// - Speech recognition runs only on this iPhone, never on a server. If the iPhone can't do that,
//   the word check turns off and only timing is used.
// - Where data lives: one file on this iPhone, encrypted when the phone is locked, not in iCloud backups.
// - Data leaves the phone only if a grown-up taps Share on a summary.
// - Sessions are deleted automatically after 90 days (ObservationStore.retentionDays).
// - How to delete everything now (Grown-ups → Raw observations → Delete all data, or your summary screen).
// - The grown-up gate is a speed bump for kids, not real security.
// - ReadRight is not a diagnostic tool.
// Also add a short kid version: "Pip listens only when the ear is glowing. Your voice is never saved."

struct PrivacyView: View {
    var body: some View {
        List {
            Text("TODO(team): privacy information for families goes here.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Privacy")
    }
}
