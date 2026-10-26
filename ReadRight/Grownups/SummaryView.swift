import SwiftUI

/// The family summary: the screening recommendation first, then each area at a glance, what went well,
/// one card for each area specialists look at (with a bar for each item), patterns that repeated,
/// background, and a Share button to send the results to a doctor or specialist.
struct SummaryView: View {
    @Environment(ObservationStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @State private var showingSample = AppFlags.sampleSummary

    var body: some View {
        let observations = showingSample ? SummaryBuilder.sampleObservations() : store.observations
        let summary = SummaryBuilder.build(from: observations, profile: profiles.profile, isSample: showingSample)
        VStack(alignment: .leading, spacing: 18) {
            if summary.isEmpty {
                emptyState
            } else {
                if showingSample {
                    HStack(alignment: .top) {
                        Text("Example values for layout only. These numbers are made up and aren't any real child's results.")
                            .themed(.body, 15)
                        Spacer(minLength: 8)
                        Button("Clear") { showingSample = false }
                            .buttonStyle(ChunkyButtonStyle(fill: Theme.panel, radius: 12, drop: 3, size: 14))
                    }
                    .foregroundStyle(Theme.warnInk)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.warnBackground))
                }
                header(summary)
                ReferralCard(referral: summary.referral)
                AtAGlance(summary: summary)
                card(title: "What went well", fill: Theme.soft) {
                    bulletList(summary.strengths.isEmpty ? ["Play an island to see this."] : summary.strengths)
                }

                Text("What specialists look at").themed(.display, 22).foregroundStyle(Theme.ink)
                Text("Reading specialists check a handful of skills. Here's what Pip saw for each one today. Nothing is compared with other children.")
                    .themed(.body, 15)
                    .foregroundStyle(Theme.inkSoft)
                ForEach(summary.areas) { area in
                    AreaCard(area: area)
                }
                if !summary.notPlayed.isEmpty {
                    Text("Not played yet: \(summary.notPlayed.map(\.title).joined(separator: ", ")).")
                        .themed(.body, 15)
                        .foregroundStyle(Theme.muted)
                }

                card(title: "Patterns that repeated") {
                    if summary.patterns.isEmpty {
                        Text("Nothing repeated in this short session. One-off mix-ups aren't shown as patterns.")
                            .themed(.body, 15)
                    } else {
                        bulletList(summary.patterns)
                        Text("Something is listed only when it happened at least twice. Mixing up look-alike or sound-alike letters is common while children learn letters, so it's something to notice, not something to worry about on its own.")
                            .themed(.body, 13)
                            .foregroundStyle(Theme.muted)
                    }
                }

                if !summary.background.isEmpty {
                    card(title: "Background you shared") { bulletList(summary.background) }
                }

                card(title: "About these results", fill: Theme.soft) {
                    Text(SummaryBuilder.aboutResults)
                        .themed(.body, 15)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ShareLink(item: SummaryBuilder.text(summary)) {
                    Label("Share results with a doctor or specialist", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 18))
                Text("You choose who gets it, for example by email, Messages or AirDrop. ReadRight never sends anything by itself.")
                    .themed(.body, 13)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Family summary")
            Text("Nothing to show yet").themed(.display, 26).foregroundStyle(Theme.ink)
            Text("The summary is built only from what happens during play. Visit an island with your child and come back, or look at a layout example with made-up values.")
                .themed(.body, 16)
                .foregroundStyle(Theme.inkSoft)
            Button("Show a layout example (made-up values)") { showingSample = true }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.panel, radius: 14, drop: 4, size: 16))
        }
    }

    private func header(_ summary: FamilySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Family summary · \(summary.date.formatted(date: .long, time: .omitted))")
            Text("\(summary.nickname)'s walk through Letterwood").themed(.display, 26).foregroundStyle(Theme.ink)
            Text("A snapshot of one day's play: \(summary.islandsPlayed.count) island\(summary.islandsPlayed.count == 1 ? "" : "s"), \(summary.itemsTried) tries. Children have good days and tired days, so playing again on another day makes the results more reliable.")
                .themed(.body, 15)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func card<Content: View>(title: String, fill: Color = Theme.background, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).themed(.display, 18).foregroundStyle(Theme.ink)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.ink, lineWidth: 2))
    }
}

func bulletList(_ items: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        ForEach(items, id: \.self) { item in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").themed(.body, 15)
                Text(item).themed(.body, 15).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.ink)
        }
    }
}

/// One area card: what it is, what Pip saw, and a bar for each item.
private struct AreaCard: View {
    let area: FamilySummary.Area

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(area.kind.title).themed(.display, 18).foregroundStyle(Theme.ink)
                    Text("\(area.kind.activity.title) · specialists call this \(area.kind.specialistTerm)")
                        .themed(.body, 13)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if area.looksHardToday {
                    StatusChip(text: area.hardDays >= 2 ? "Tricky on \(area.hardDays) days" : "Tricky today")
                }
            }
            Text(area.kind.whatItIs).themed(.body, 15).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            bulletList(area.observed)
            if !area.bars.isEmpty {
                ItemBars(bars: area.bars, medianMs: area.medianMs)
                if let caption = area.chartCaption {
                    Text(caption).themed(.body, 13).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.background))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.ink, lineWidth: 2))
    }
}

/// "Tricky today." A calm icon and words, never color alone, and nothing that looks like an alarm.
private struct StatusChip: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .themed(.body, 13)
            .foregroundStyle(Theme.warnInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.warnBackground))
            .overlay(Capsule().strokeBorder(Theme.warnInk.opacity(0.5), lineWidth: 1.5))
    }
}

/// A bar per item, with the child's own middle time as a dashed line.
/// Bars that needed help are striped and say so in words, so the meaning never depends on color.
struct ItemBars: View {
    let bars: [FamilySummary.Bar]
    let medianMs: Int?

    var body: some View {
        let longest = max(bars.map(\.ms).max() ?? 1, medianMs ?? 0, 1)
        VStack(spacing: 6) {
            ForEach(bars) { bar in
                HStack(spacing: 8) {
                    Text(bar.label)
                        .themed(.body, 14)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .frame(width: 58, alignment: .leading)
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Theme.soft)
                            if bar.ms > 0 {
                                BarFill(striped: bar.neededHelp)
                                    .frame(width: max(4, width * CGFloat(bar.ms) / CGFloat(longest)))
                            }
                            if let medianMs {
                                DashedLine()
                                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                                    .frame(width: 2)
                                    .padding(.vertical, -4)
                                    .offset(x: width * CGFloat(medianMs) / CGFloat(longest) - 1)
                            }
                        }
                    }
                    .frame(height: 16)
                    Text(valueText(bar))
                        .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                        .frame(width: 124, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(bar.label): \(valueText(bar))")
            }
        }
    }

    private func valueText(_ bar: FamilySummary.Bar) -> String {
        let time = bar.ms > 0 ? SummaryBuilder.seconds(bar.ms) : "–"
        return bar.note.map { "\(time) · \($0)" } ?? time
    }
}

private struct BarFill: View {
    let striped: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4)
        if striped {
            shape.fill(Theme.sun)
                .overlay(Stripes().stroke(Theme.earth, lineWidth: 3).clipShape(shape))
        } else {
            shape.fill(Theme.mintDark)
        }
    }
}

private struct Stripes: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            var x = -rect.height
            while x < rect.width {
                path.move(to: CGPoint(x: x, y: rect.maxY))
                path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                x += 8
            }
        }
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

/// The five areas in one small table, so a grown-up can see in a few seconds what went smoothly
/// and what was tricky. Each status has an icon and words, never color alone.
private struct AtAGlance: View {
    let summary: FamilySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("At a glance").themed(.display, 18).foregroundStyle(Theme.ink)
            ForEach(FamilySummary.AreaKind.allCases) { kind in
                HStack(spacing: 8) {
                    Text(kind.title)
                        .themed(.body, 15)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if let area = summary.areas.first(where: { $0.kind == kind }) {
                        badge(for: area)
                    } else {
                        Label("Not played yet", systemImage: "circle.dashed")
                            .themed(.body, 13)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Text("Smooth: at least 3 out of 4 answers right. Tricky: fewer than half. Speed is never judged, because ReadRight has no age norms.")
                .themed(.body, 12)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.ink, lineWidth: 2))
    }

    private func badge(for area: FamilySummary.Area) -> some View {
        let (text, icon, ink, fill): (String, String, Color, Color) = switch area.status {
        case .smooth: (area.kind == .rapidNaming ? "Named them all" : "Went smoothly", "checkmark.circle.fill", Theme.mintDark, Color(hex: 0xD9F5E9))
        case .mixed: ("Some tricky ones", "circle.lefthalf.filled", Theme.inkSoft, Theme.soft)
        case .tricky: (area.hardDays >= 2 ? "Tricky on \(area.hardDays) days" : "Tricky today", "info.circle", Theme.warnInk, Theme.warnBackground)
        case .notEnough: ("Not enough to say", "ellipsis.circle", Theme.muted, Theme.background)
        }
        return Label(text, systemImage: icon)
            .themed(.body, 13)
            .foregroundStyle(ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }
}

/// The screening result, at the top of every summary: a clear next step, why, and who to see.
private struct ReferralCard: View {
    let referral: Referral

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(ink)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Screening result")
                    Text(referral.headline)
                        .themed(.display, 21)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(referral.detail)
                .themed(.body, 15)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !referral.reasons.isEmpty {
                Text("Why").themed(.display, 15).foregroundStyle(Theme.ink)
                bulletList(referral.reasons)
            }
            if !referral.whoToSee.isEmpty {
                Text("Who to see").themed(.display, 15).foregroundStyle(Theme.ink)
                bulletList(referral.whoToSee)
                Text("Use the Share button at the bottom to send these results to them.")
                    .themed(.body, 13)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ink, lineWidth: Theme.line))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch referral.level {
        case .seeSpecialist: "stethoscope"
        case .checkIn: "hand.raised.fill"
        case .noFollowUp: "checkmark.circle.fill"
        case .notEnough: "ellipsis.circle"
        }
    }

    private var ink: Color {
        switch referral.level {
        case .seeSpecialist: Theme.warnInk
        case .checkIn: Theme.earth
        case .noFollowUp: Theme.mintDark
        case .notEnough: Theme.muted
        }
    }

    private var fill: Color {
        switch referral.level {
        case .seeSpecialist: Theme.warnBackground
        case .checkIn: Theme.soft
        case .noFollowUp: Color(hex: 0xD9F5E9)
        case .notEnough: Theme.background
        }
    }
}
