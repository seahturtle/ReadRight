import SwiftUI

/// The island map, from the prototype: four islands in any order, each showing how many fireflies
/// were lit in this session, plus Comfort settings and the grown-up area.
struct LetterwoodMapView: View {
    @Environment(ObservationStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @State private var showingComfort = false

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.sun)
                        Text("ReadRight").themed(.display, 24).foregroundStyle(Theme.ink)
                    }
                    .accessibilityElement(children: .combine)
                    VStack(spacing: 4) {
                        Text("Pick an island, \(profiles.profile.nickname)")
                            .themed(.display, 30)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("Visit them in any order. Each one takes about 2 minutes.")
                            .themed(.body, 16)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    ForEach(Activity.allCases) { activity in
                        NavigationLink(value: Route(activity)) {
                            IslandCard(activity: activity, lit: lit(activity), steps: steps(activity))
                        }
                        .buttonStyle(.plain)
                    }
                    // TODO(team): show ParentGateView before the grown-up area.
                    NavigationLink(value: Route.grownUps) {
                        Label("Grown-up summary", systemImage: "chart.bar.doc.horizontal")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.sun, size: 18))
                }
                .padding(16)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Comfort") { showingComfort = true }
                    .themed(.body, 15)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.grownUps) { Text("Grown-ups").themed(.body, 15) }
            }
        }
        .sheet(isPresented: $showingComfort) { ComfortSheet() }
    }

    private func steps(_ activity: Activity) -> Int {
        switch activity {
        case .soundSprings: ItemBank.soundSprings.count
        case .echoCave: ItemBank.echoCave(for: profiles.profile.ageBand).count
        case .wordWoods: ItemBank.wordWoods(for: profiles.profile.ageBand).count
        case .fireflyDash: 1
        }
    }

    private func lit(_ activity: Activity) -> Int {
        min(store.observations.filter { $0.sessionID == store.sessionID && $0.activity == activity }.count, steps(activity))
    }
}

private struct IslandCard: View {
    let activity: Activity
    let lit: Int
    let steps: Int

    var body: some View {
        HStack(spacing: 14) {
            IslandArt(activity: activity)
                .frame(width: 112)
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title).themed(.display, 22).foregroundStyle(Theme.ink)
                Text(activity.subtitle).themed(.body, 15).foregroundStyle(Theme.inkSoft)
                Text(steps == 1 ? "1 big dash · about 1 minute" : "\(steps) steps · about 2 minutes")
                    .themed(.body, 13)
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 5) {
                    ForEach(0..<steps, id: \.self) { index in
                        Circle()
                            .fill(index < lit ? Theme.sun : .clear)
                            .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                            .frame(width: 12, height: 12)
                            .shadow(color: index < lit ? Theme.sun : .clear, radius: 4)
                    }
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .chunky(radius: 28, drop: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.title). \(activity.subtitle). \(lit) of \(steps) fireflies lit.")
    }
}
