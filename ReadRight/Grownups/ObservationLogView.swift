import SwiftUI

/// A testing screen that shows exactly what ReadRight has saved on this iPhone.
/// The family summary (SummaryView) is built from these same observations.
struct ObservationLogView: View {
    @Environment(ObservationStore.self) private var store
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                Text("Everything ReadRight saved on this iPhone: numbers and labels only, never audio or transcripts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(Activity.allCases) { activity in
                let rows = store.observations.filter { $0.activity == activity }
                if !rows.isEmpty {
                    Section(activity.title) {
                        ForEach(rows.reversed()) { observation in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(observation.target).font(.headline)
                                Text(observation.details)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(observation.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            if !store.observations.isEmpty {
                Section {
                    Button("Delete all data", role: .destructive) { confirmingDelete = true }
                }
            }
        }
        .overlay {
            if store.observations.isEmpty {
                ContentUnavailableView("Nothing saved yet", systemImage: "sparkles", description: Text("Play a game, then come back."))
            }
        }
        .confirmationDialog("Delete everything ReadRight saved on this iPhone?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) { store.deleteAll() }
        }
        .navigationTitle("Raw observations")
    }
}

extension ItemObservation {
    /// One line of the stored values, for the testing log.
    var details: String {
        var parts: [String] = []
        if let itemTag { parts.append(itemTag) }
        if let firstTry { parts.append(firstTry ? "first try" : "\(tries ?? 0) tries") }
        if let responseMs { parts.append("tap \(responseMs) ms") }
        if let distractorChosen { parts.append("picked \(distractorChosen)" + (distractorKind.map { " (\($0))" } ?? "")) }
        if hintShown == true { parts.append("hint") }
        if let replays, replays > 0 { parts.append("\(replays) replays") }
        if let onsetMs { parts.append("voice \(onsetMs) ms") }
        if let namingMs { parts.append("named in \(namingMs) ms") }
        if let wordCheck { parts.append("check: \(wordCheck.rawValue)") }
        if let grownUpMark { parts.append("grown-up: \(grownUpMark.rawValue)") }
        if let namedAll { parts.append("named \(namedAll.rawValue)") }
        if let timing { parts.append("timed by \(timing.rawValue)") }
        return parts.joined(separator: " · ")
    }
}
