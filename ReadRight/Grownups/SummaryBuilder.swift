import Foundation

/// The family summary, organized by the areas reading specialists look at.
///
/// Every rule here is plain and explainable, with no machine learning and no score:
/// 1. Only this child's own play is used. Nothing is compared with other children or age norms.
/// 2. Times are compared only with the child's own middle (median) time.
/// 3. A pattern is listed only if it happened at least twice.
/// 4. A grown-up's mark overrides the automatic word check. "Unclear" is never counted as wrong.
/// 5. An area was "tricky today" when fewer than half of the answers Pip could judge were right.
///    When that happens on more than one calendar day, the summary says so, because persistence matters.
/// 6. It never says whether a child has dyslexia.
struct FamilySummary {
    enum AreaKind: String, CaseIterable, Identifiable {
        case letterSounds, phonemeAwareness, wordReading, decoding, rapidNaming

        var id: String { rawValue }
    }

    struct Bar: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let ms: Int
        let neededHelp: Bool
        let note: String?
    }

    struct Area: Identifiable {
        let kind: AreaKind
        var id: AreaKind { kind }
        var observed: [String] = []
        var bars: [Bar] = []
        var medianMs: Int?
        var chartCaption: String?
        var looksHardToday = false
        /// How many different days this area looked hard on, including today.
        var hardDays = 0
    }

    var nickname: String
    var date: Date
    var isSample = false
    var itemsTried = 0
    var islandsPlayed: [Activity] = []
    var notPlayed: [Activity] = []
    var strengths: [String] = []
    var areas: [Area] = []
    var patterns: [String] = []
    var background: [String] = []
    var nextSteps: [String] = []

    var isEmpty: Bool { itemsTried == 0 }
}

extension FamilySummary.AreaKind {
    var title: String {
        switch self {
        case .letterSounds: "Letter sounds"
        case .phonemeAwareness: "Hearing the sounds in words"
        case .wordReading: "Reading real words"
        case .decoding: "Sounding out made-up words"
        case .rapidNaming: "Naming things quickly"
        }
    }

    /// The name a teacher or specialist would use, so a family can mention it.
    var specialistTerm: String {
        switch self {
        case .letterSounds: "letter–sound knowledge"
        case .phonemeAwareness: "phonological (phonemic) awareness"
        case .wordReading: "word reading"
        case .decoding: "decoding, or nonword reading"
        case .rapidNaming: "rapid automatized naming (RAN)"
        }
    }

    var activity: Activity {
        switch self {
        case .letterSounds: .soundSprings
        case .phonemeAwareness: .echoCave
        case .wordReading, .decoding: .wordWoods
        case .rapidNaming: .fireflyDash
        }
    }

    var whatItIs: String {
        switch self {
        case .letterSounds: "Knowing which letter goes with a sound. It's one of the building blocks of reading."
        case .phonemeAwareness: "Hearing and changing the small sounds inside spoken words. It's one of the strongest early links to learning to read."
        case .wordReading: "Reading short, common words out loud."
        case .decoding: "Sounding out words that can't be memorized, so they show how a child uses letter sounds."
        case .rapidNaming: "Saying the names of familiar things, here colors, quickly and smoothly."
        }
    }
}

enum SummaryBuilder {
    enum Judged: Equatable {
        case yes, no, unknown
    }

    /// Whether a spoken answer was right. A grown-up's mark wins. "Unclear", "skipped" and silence stay unknown,
    /// because a child can skip or go quiet for many reasons (a phone call, shyness, the app closing).
    static func judge(_ observation: ItemObservation) -> Judged {
        switch observation.grownUpMark {
        case .readIt: return .yes
        case .neededHelp: return .no
        case .skipped: return .unknown
        case nil: return observation.wordCheck == .matched ? .yes : .unknown
        }
    }

    /// Play on the same calendar day counts as one day, even if the app was closed and reopened.
    static func day(_ observation: ItemObservation) -> Date {
        Calendar.current.startOfDay(for: observation.recordedAt)
    }

    static func build(from all: [ItemObservation], profile: Profile, isSample: Bool = false) -> FamilySummary {
        var summary = FamilySummary(nickname: profile.nickname, date: .now, isSample: isSample)
        summary.background = background(for: profile)
        guard let latest = all.max(by: { $0.recordedAt < $1.recordedAt }) else { return summary }

        let latestDay = day(latest)
        let today = all.filter { day($0) == latestDay }
        let days = Dictionary(grouping: all, by: day).values
        summary.date = latest.recordedAt
        summary.itemsTried = today.count
        summary.islandsPlayed = Activity.allCases.filter { activity in today.contains { $0.activity == activity } }
        summary.notPlayed = Activity.allCases.filter { !summary.islandsPlayed.contains($0) }

        for kind in FamilySummary.AreaKind.allCases {
            let todays = observations(for: kind, in: today)
            guard !todays.isEmpty else { continue }
            var area = makeArea(kind, todays, all: all, nickname: profile.nickname)
            area.looksHardToday = looksHard(kind, todays)
            area.hardDays = days.filter { looksHard(kind, observations(for: kind, in: Array($0))) }.count
            summary.areas.append(area)
        }
        summary.strengths = strengths(today)
        summary.patterns = patterns(today)
        summary.nextSteps = nextSteps(summary, profile: profile)
        return summary
    }

    static func observations(for kind: FamilySummary.AreaKind, in observations: [ItemObservation]) -> [ItemObservation] {
        let madeUp = SpeakItem.Tag.madeUp.rawValue
        return switch kind {
        case .letterSounds: observations.filter { $0.activity == .soundSprings }
        case .phonemeAwareness: observations.filter { $0.activity == .echoCave }
        case .wordReading: observations.filter { $0.activity == .wordWoods && $0.itemTag != madeUp }
        case .decoding: observations.filter { $0.activity == .wordWoods && $0.itemTag == madeUp }
        case .rapidNaming: observations.filter { $0.activity == .fireflyDash }
        }
    }

    /// Fewer than half of the judged answers were right. Needs enough answers to say anything.
    static func looksHard(_ kind: FamilySummary.AreaKind, _ observations: [ItemObservation]) -> Bool {
        switch kind {
        case .letterSounds:
            guard observations.count >= 4 else { return false }
            return observations.filter { $0.firstTry == true }.count * 2 < observations.count
        case .phonemeAwareness, .wordReading, .decoding:
            let known = observations.map(judge).filter { $0 != .unknown }
            guard known.count >= (kind == .decoding ? 2 : 3) else { return false }
            return known.filter { $0 == .yes }.count * 2 < known.count
        case .rapidNaming:
            // There are no age norms here, so speed alone is never called hard. Only missing most colors is.
            return observations.contains { $0.namedAll == .few }
        }
    }

    static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    static func seconds(_ ms: Int) -> String {
        String(format: "%.1f s", Double(ms) / 1000)
    }

    // MARK: - Areas

    private static func makeArea(_ kind: FamilySummary.AreaKind, _ items: [ItemObservation], all: [ItemObservation], nickname: String) -> FamilySummary.Area {
        var area = FamilySummary.Area(kind: kind)
        let ownMiddle = "The dashed line is \(nickname)'s own middle time."
        switch kind {
        case .letterSounds:
            let first = items.filter { $0.firstTry == true }.count
            let hints = items.filter { $0.hintShown == true }.count
            area.medianMs = median(items.compactMap(\.responseMs))
            area.observed.append("Matched \(first) of \(items.count) first sounds to letters on the first try.")
            if let middle = area.medianMs {
                area.observed.append("Middle time to the first tap: \(seconds(middle)). This includes listening to Pip.")
            }
            if hints > 0 { area.observed.append("Pip showed the glowing hint \(hints) time\(hints == 1 ? "" : "s").") }
            area.bars = items.map { item in
                let missed = item.firstTry == false
                return .init(label: item.target, ms: item.responseMs ?? 0, neededHelp: missed, note: missed ? (item.hintShown == true ? "hint" : "2nd try") : nil)
            }
            area.chartCaption = "Time to the first tap for each word. Striped bars needed another try. \(ownMiddle)"

        case .phonemeAwareness, .wordReading, .decoding:
            let judged = items.map(judge)
            let yes = judged.filter { $0 == .yes }.count
            let known = judged.filter { $0 != .unknown }.count
            let unknown = items.count - known
            area.medianMs = median(items.compactMap(\.onsetMs))
            switch kind {
            case .phonemeAwareness:
                area.observed.append("Solved \(yes) of \(known) sound puzzles that could be judged.")
                if let comparison = tagComparison(items, .single, "Single first sounds (cat → at)", .cluster, "first sound of a blend (snail → nail)") {
                    area.observed.append(comparison)
                }
            case .wordReading:
                area.observed.append("Read \(yes) of \(known) real words that could be judged.")
                let short = median(items.filter { $0.itemTag == SpeakItem.Tag.short.rawValue }.compactMap(\.onsetMs))
                let blend = median(items.filter { $0.itemTag == SpeakItem.Tag.blend.rawValue }.compactMap(\.onsetMs))
                if let short, let blend {
                    area.observed.append("Short words started in about \(seconds(short)). Words that start with two consonants, like frog, in about \(seconds(blend)).")
                }
            default:
                area.observed.append("Read \(yes) of \(known) made-up names, as marked by a grown-up.")
                let realWords = observations(for: .wordReading, in: all.filter { $0.sessionID == items.first?.sessionID })
                if let madeUp = area.medianMs, let real = median(realWords.compactMap(\.onsetMs)) {
                    area.observed.append("Made-up names started in about \(seconds(madeUp)). Real words in about \(seconds(real)).")
                }
            }
            if let middle = area.medianMs {
                area.observed.append("Middle time from the green light to the first sound: \(seconds(middle)).")
            }
            if unknown > 0 {
                area.observed.append("\(unknown) answer\(unknown == 1 ? " was" : "s were") skipped, silent or unclear to Pip, so \(unknown == 1 ? "it wasn't" : "they weren't") counted.")
            }
            area.bars = zip(items, judged).map { item, result in
                let note: String? = switch result {
                case .no: "help"
                case .unknown: item.grownUpMark == .skipped ? "skipped" : (item.onsetMs == nil ? "no answer" : "unclear")
                case .yes: nil
                }
                return .init(label: item.target, ms: item.onsetMs ?? 0, neededHelp: result == .no, note: note)
            }
            area.chartCaption = "Time from the green light to the first sound. Striped bars needed help. \(ownMiddle)"

        case .rapidNaming:
            let latest = items.max { $0.recordedAt < $1.recordedAt }
            if let latest, let naming = latest.namingMs {
                // Time per firefly only makes sense when all 20 were named.
                area.observed.append(latest.namedAll == .all
                    ? "Naming all 20 fireflies took \(seconds(naming)), about \(seconds(naming / 20)) per firefly."
                    : "Naming took \(seconds(naming)).")
            }
            if let onset = latest?.onsetMs { area.observed.append("Started \(seconds(onset)) after the light turned green.") }
            if let named = latest?.namedAll {
                let words = switch named {
                case .all: "all 20"
                case .most: "most of them"
                case .few: "a few of them"
                }
                area.observed.append("A grown-up said they named \(words).")
            }
            if latest?.timing == .grownUpTaps { area.observed.append("Timed by a grown-up's taps, so it's less exact than voice timing.") }
            area.observed.append("ReadRight has no age norms, so it can't say whether this is quick or slow for \(nickname)'s age. Specialists use tested norms for that.")
            // Every dash so far, so a family can see their child's own trend.
            let dashes = all.filter { $0.activity == .fireflyDash && $0.namingMs != nil }.sorted { $0.recordedAt < $1.recordedAt }
            area.bars = dashes.map { dash in
                .init(label: dash.recordedAt.formatted(.dateTime.month(.abbreviated).day()), ms: dash.namingMs ?? 0, neededHelp: dash.namedAll == .few, note: dash.namedAll == .few ? "a few named" : nil)
            }
            area.medianMs = median(dashes.compactMap(\.namingMs))
            area.chartCaption = "Total naming time for each Firefly Dash, so you can see \(nickname)'s own trend over days."
        }
        return area
    }

    /// "Single sounds: 3 of 3. Blends: 1 of 3." Only when both kinds have judged answers.
    private static func tagComparison(_ items: [ItemObservation], _ first: SpeakItem.Tag, _ firstLabel: String, _ second: SpeakItem.Tag, _ secondLabel: String) -> String? {
        func counts(_ tag: SpeakItem.Tag) -> (yes: Int, known: Int) {
            let judged = items.filter { $0.itemTag == tag.rawValue }.map(judge).filter { $0 != .unknown }
            return (judged.filter { $0 == .yes }.count, judged.count)
        }
        let a = counts(first)
        let b = counts(second)
        guard a.known > 0, b.known > 0 else { return nil }
        return "\(firstLabel): \(a.yes) of \(a.known). The \(secondLabel): \(b.yes) of \(b.known)."
    }

    // MARK: - Strengths, patterns, background, next steps

    private static func strengths(_ today: [ItemObservation]) -> [String] {
        var lines: [String] = []
        let sounds = observations(for: .letterSounds, in: today)
        let firstTry = sounds.filter { $0.firstTry == true }.count
        if firstTry > 0 { lines.append("Matched \(firstTry) first sound\(firstTry == 1 ? "" : "s") to letters on the first try.") }
        let wobbles = sounds.filter { ($0.tries ?? 1) > 1 }.count
        if wobbles > 0 { lines.append("Kept going after \(wobbles) wobbly stone\(wobbles == 1 ? "" : "s") and found the answer.") }
        let puzzles = observations(for: .phonemeAwareness, in: today).map(judge).filter { $0 == .yes }.count
        if puzzles > 0 { lines.append("Solved \(puzzles) sound puzzle\(puzzles == 1 ? "" : "s") in Echo Cave.") }
        let words = observations(for: .wordReading, in: today).map(judge).filter { $0 == .yes }.count
        if words > 0 { lines.append("Read \(words) real word\(words == 1 ? "" : "s") out loud.") }
        let names = observations(for: .decoding, in: today).map(judge).filter { $0 == .yes }.count
        if names > 0 { lines.append("Sounded out \(names) made-up name\(names == 1 ? "" : "s").") }
        let dashes = observations(for: .rapidNaming, in: today)
        if dashes.contains(where: { $0.namedAll == .all }) {
            lines.append("Named all 20 fireflies.")
        } else if !dashes.isEmpty {
            lines.append("Finished a Firefly Dash.")
        }
        return lines
    }

    /// Only things that happened at least twice.
    static func patterns(_ today: [ItemObservation]) -> [String] {
        var lines: [String] = []
        let missedFirst = observations(for: .letterSounds, in: today).filter { $0.firstTry == false }
        let mirror = missedFirst.filter { $0.distractorKind == LetterItem.DistractorKind.mirrorImage.rawValue }.count
        let soundAlike = missedFirst.filter { $0.distractorKind == LetterItem.DistractorKind.soundAlike.rawValue }.count
        if mirror >= 2 { lines.append("In Sound Springs, picked a mirror-image letter first \(mirror) times (like d for b).") }
        if soundAlike >= 2 { lines.append("In Sound Springs, picked a sound-alike letter first \(soundAlike) times (like p for b).") }

        for activity in [Activity.echoCave, .wordWoods] {
            let items = today.filter { $0.activity == activity }
            let help = items.filter { $0.grownUpMark == .neededHelp }.count
            if help >= 2 { lines.append("In \(activity.title), a grown-up marked \"needed help\" \(help) times.") }
            let onsets = items.compactMap(\.onsetMs)
            if onsets.count >= 4, let middle = median(onsets) {
                let slow = onsets.filter { Double($0) > Double(middle) * 1.5 }.count
                if slow >= 2 { lines.append("In \(activity.title), started noticeably later than their own usual time on \(slow) items.") }
            }
        }

        let words = today.filter { $0.activity == .wordWoods }
        let real = words.filter { $0.itemTag != SpeakItem.Tag.madeUp.rawValue }.compactMap(\.onsetMs)
        let madeUp = words.filter { $0.itemTag == SpeakItem.Tag.madeUp.rawValue }.compactMap(\.onsetMs)
        if real.count >= 2, madeUp.count >= 2, let realMiddle = median(real), let madeUpMiddle = median(madeUp),
           Double(madeUpMiddle) > Double(realMiddle) * 1.5 {
            lines.append("Made-up names took noticeably longer to start than real words.")
        }

        let puzzles = observations(for: .phonemeAwareness, in: today)
        let singles = puzzles.filter { $0.itemTag == SpeakItem.Tag.single.rawValue }.map(judge).filter { $0 != .unknown }
        let clusters = puzzles.filter { $0.itemTag == SpeakItem.Tag.cluster.rawValue }.map(judge).filter { $0 != .unknown }
        if singles.filter({ $0 == .yes }).count >= 2, clusters.count >= 2, clusters.filter({ $0 == .no }).count >= 2 {
            lines.append("In Echo Cave, puzzles with blends (snail → nail) were harder than single-sound puzzles.")
        }
        return lines
    }

    static func background(for profile: Profile) -> [String] {
        var lines: [String] = []
        if profile.familyHistory == .yes {
            lines.append("You said a parent, brother or sister has had trouble learning to read. Reading differences often run in families, so it's one of the first things a specialist asks about. Many children with family history learn to read without any trouble.")
        }
        if profile.speechDelay == .yes {
            lines.append("You said your child started talking later or had speech or language help. Early speech and language differences are linked to later reading differences, so a speech-language pathologist's notes are useful to share with a reading specialist.")
        }
        if profile.visionHearingChecked == .no || profile.visionHearingChecked == .notSure {
            lines.append("Vision and hearing may not have been checked recently. Both affect reading and listening games, so it's worth asking your pediatrician.")
        }
        if profile.speaksOtherLanguages == .yes {
            lines.append("Your child speaks another language at home. That's a strength! Children learning English may say words differently than the game expects, so treat word results with extra care.")
        }
        return lines
    }

    private static func nextSteps(_ summary: FamilySummary, profile: Profile) -> [String] {
        var lines: [String] = []
        let hard = summary.areas.filter(\.looksHardToday)
        let repeated = summary.areas.filter { $0.hardDays >= 2 }
        if hard.isEmpty {
            lines.append("Nothing was tricky in today's play. If you still have concerns about reading, trust them and talk with your child's teacher.")
        } else {
            lines.append("Tricky today: \(hard.map(\.kind.title).joined(separator: ", ")). One day of play says very little on its own, so try again on another day.")
        }
        if !repeated.isEmpty {
            lines.append("Tricky on more than one day: \(repeated.map(\.kind.title).joined(separator: ", ")). Things that keep showing up are worth mentioning to your child's teacher or pediatrician.")
        }
        if !hard.isEmpty, profile.familyHistory == .yes {
            lines.append("Because reading difficulties run in your family, it's worth sharing what you notice with your child's teacher.")
        }
        lines.append("In California, public schools screen every student in kindergarten through 2nd grade for reading difficulties each year, and share the results with families. Ask your child's school for them.")
        lines.append("Only a qualified professional, like a school psychologist or reading specialist, can assess dyslexia. You're welcome to bring this summary as a conversation starter.")
        return lines
    }

    // MARK: - Sharing

    /// Plain text for the Share button. Nothing is sent unless the grown-up picks where.
    static func text(_ summary: FamilySummary) -> String {
        var lines = ["ReadRight family summary for \(summary.nickname), \(summary.date.formatted(date: .long, time: .omitted))"]
        if summary.isSample { lines.append("EXAMPLE VALUES FOR LAYOUT ONLY. NOT A REAL CHILD.") }
        lines.append("These are observations from play. They are not a test and not a diagnosis.")
        lines.append("")
        lines.append("What went well:")
        lines += summary.strengths.map { "- \($0)" }
        for area in summary.areas {
            lines.append("")
            lines.append("\(area.kind.title) (\(area.kind.specialistTerm)):")
            lines += area.observed.map { "- \($0)" }
        }
        lines.append("")
        lines.append("Patterns that repeated:")
        lines += summary.patterns.isEmpty ? ["- None in this session."] : summary.patterns.map { "- \($0)" }
        if !summary.background.isEmpty {
            lines.append("")
            lines.append("Background from the grown-up:")
            lines += summary.background.map { "- \($0)" }
        }
        lines.append("")
        lines.append("Next steps:")
        lines += summary.nextSteps.map { "- \($0)" }
        return lines.joined(separator: "\n")
    }

    // MARK: - Layout example

    /// Made-up observations for the "layout example" button. Always labeled as not a real child.
    static func sampleObservations() -> [ItemObservation] {
        let session = UUID()
        var result: [ItemObservation] = []
        let sounds: [(String, Int, Bool, String?)] = [
            ("bus", 2600, false, "mirrorImage"), ("dog", 2100, true, nil), ("sun", 1800, true, nil), ("pencil", 3100, false, "mirrorImage"),
            ("moon", 1900, true, nil), ("fish", 2900, false, "soundAlike"), ("tree", 2000, true, nil), ("cup", 2200, true, nil),
        ]
        for (word, ms, first, kind) in sounds {
            var o = ItemObservation(sessionID: session, activity: .soundSprings, itemID: "ss-\(word)", target: word)
            o.firstTry = first
            o.tries = first ? 1 : 2
            o.responseMs = ms
            o.distractorKind = kind
            o.distractorChosen = kind == nil ? nil : "d"
            result.append(o)
        }
        let puzzles: [(String, String, Int, WordCheck, GrownUpMark?)] = [
            ("at", "single", 1400, .matched, nil), ("arm", "single", 1600, .matched, nil), ("nail", "cluster", 2900, .unclear, .neededHelp),
            ("eat", "single", 1500, .matched, nil), ("top", "cluster", 3300, .unclear, .neededHelp), ("us", "single", 1700, .unclear, nil),
        ]
        for (word, tag, ms, check, mark) in puzzles {
            var o = ItemObservation(sessionID: session, activity: .echoCave, itemID: "ec-\(word)", target: word)
            o.itemTag = tag
            o.onsetMs = ms
            o.wordCheck = check
            o.grownUpMark = mark
            result.append(o)
        }
        let words: [(String, String, Int, WordCheck, GrownUpMark?)] = [
            ("cat", "short", 1200, .matched, nil), ("sun", "short", 1100, .matched, nil), ("zib", "madeUp", 2600, .unavailable, .readIt),
            ("pig", "short", 1300, .matched, nil), ("frog", "blend", 1900, .matched, nil), ("fep", "madeUp", 3000, .unavailable, .neededHelp),
            ("bed", "short", 1250, .matched, nil), ("stop", "blend", 2100, .unclear, .readIt),
        ]
        for (word, tag, ms, check, mark) in words {
            var o = ItemObservation(sessionID: session, activity: .wordWoods, itemID: "ww-\(word)", target: word)
            o.itemTag = tag
            o.onsetMs = ms
            o.wordCheck = check
            o.grownUpMark = mark
            result.append(o)
        }
        var dash = ItemObservation(sessionID: session, activity: .fireflyDash, itemID: "fd-grid-1", target: "20 colors")
        dash.onsetMs = 900
        dash.namingMs = 31000
        dash.namedAll = .all
        dash.timing = .voice
        result.append(dash)
        return result
    }
}
