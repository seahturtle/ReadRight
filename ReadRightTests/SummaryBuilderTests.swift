import Foundation
import Testing
@testable import ReadRight

/// The family summary's rules, checked with small made-up sessions.
struct SummaryBuilderTests {
    private let profile = Profile(nickname: "Robin")

    private func echo(_ session: UUID, _ target: String, check: WordCheck, mark: GrownUpMark? = nil, onset: Int = 1500, tag: String = "single") -> ItemObservation {
        var o = ItemObservation(sessionID: session, activity: .echoCave, itemID: "ec-\(target)", target: target)
        o.itemTag = tag
        o.wordCheck = check
        o.grownUpMark = mark
        o.onsetMs = onset
        return o
    }

    private func letter(_ session: UUID, _ word: String, firstTry: Bool, kind: String? = nil) -> ItemObservation {
        var o = ItemObservation(sessionID: session, activity: .soundSprings, itemID: "ss-\(word)", target: word)
        o.firstTry = firstTry
        o.tries = firstTry ? 1 : 2
        o.responseMs = 2000
        o.distractorKind = kind
        return o
    }

    @Test func noPlayMeansAnEmptySummary() {
        let summary = SummaryBuilder.build(from: [], profile: profile)
        #expect(summary.isEmpty)
        #expect(summary.areas.isEmpty)
    }

    @Test func aGrownUpMarkBeatsTheRecognizerAndUnclearIsNotWrong() {
        let session = UUID()
        #expect(SummaryBuilder.judge(echo(session, "nail", check: .unclear)) == .unknown)
        #expect(SummaryBuilder.judge(echo(session, "nail", check: .unclear, mark: .readIt)) == .yes)
        #expect(SummaryBuilder.judge(echo(session, "nail", check: .matched, mark: .neededHelp)) == .no)
        #expect(SummaryBuilder.judge(echo(session, "nail", check: .noResponse)) == .unknown)
        #expect(SummaryBuilder.judge(echo(session, "nail", check: .matched, mark: .skipped)) == .unknown)
    }

    @Test func anAreaLooksHardWhenFewerThanHalfOfJudgedAnswersAreRight() {
        let session = UUID()
        let hard = [
            echo(session, "at", check: .matched),
            echo(session, "nail", check: .unclear, mark: .neededHelp),
            echo(session, "top", check: .unclear, mark: .neededHelp),
            echo(session, "rain", check: .unclear, mark: .neededHelp),
        ]
        #expect(SummaryBuilder.looksHard(.phonemeAwareness, hard))

        // Unclear answers aren't counted, so three unclear and one right isn't enough to say anything.
        let unclear = [
            echo(session, "at", check: .matched),
            echo(session, "nail", check: .unclear),
            echo(session, "top", check: .unclear),
            echo(session, "rain", check: .unclear),
        ]
        #expect(!SummaryBuilder.looksHard(.phonemeAwareness, unclear))
    }

    @Test func reopeningTheAppOnTheSameDayIsStillOneDay() {
        let morning = UUID()
        let afternoon = UUID()
        let first = ["nail", "top", "rain"].map { echo(morning, $0, check: .unclear, mark: .neededHelp) }
        let second = ["nail", "top", "rain"].map { echo(afternoon, $0, check: .unclear, mark: .neededHelp) }
        let summary = SummaryBuilder.build(from: first + second, profile: profile)
        #expect(summary.areas.first { $0.kind == .phonemeAwareness }?.hardDays == 1)
    }

    @Test func hardOnMoreThanOneDayIsCounted() {
        let monday = UUID()
        let tuesday = UUID()
        func hardSession(_ id: UUID) -> [ItemObservation] {
            ["nail", "top", "rain"].map { echo(id, $0, check: .unclear, mark: .neededHelp) }
        }
        var observations = hardSession(monday)
        for var o in hardSession(tuesday) {
            o.recordedAt = Date.now.addingTimeInterval(24 * 60 * 60)
            observations.append(o)
        }
        let summary = SummaryBuilder.build(from: observations, profile: profile)
        let area = summary.areas.first { $0.kind == .phonemeAwareness }
        #expect(area?.looksHardToday == true)
        #expect(area?.hardDays == 2)
    }

    @Test func aPatternNeedsToHappenTwice() {
        let session = UUID()
        let once = [letter(session, "bat", firstTry: false, kind: "mirrorImage"), letter(session, "dog", firstTry: true)]
        #expect(SummaryBuilder.patterns(once).isEmpty)

        let twice = once + [letter(session, "pig", firstTry: false, kind: "mirrorImage")]
        #expect(SummaryBuilder.patterns(twice).contains { $0.contains("mirror-image") })
    }

    @Test func familyHistoryAddsContextButNeverAScore() {
        var withHistory = profile
        withHistory.familyHistory = .yes
        let summary = SummaryBuilder.build(from: SummaryBuilder.sampleObservations(), profile: withHistory, isSample: true)
        #expect(summary.background.contains { $0.contains("run in families") })
        #expect(summary.areas.count == FamilySummary.AreaKind.allCases.count)
        // No diagnosis words anywhere a family reads.
        let text = SummaryBuilder.text(summary).lowercased()
        for word in ["diagnosed", "risk score", "at risk", "abnormal", "you have dyslexia", "has dyslexia", "likely"] {
            #expect(!text.contains(word), "found \(word)")
        }
        #expect(text.contains("preliminary screener"))
        #expect(text.contains("result: "))
    }

    @Test func madeUpWordsAreComparedWithTheChildsOwnRealWords() {
        let summary = SummaryBuilder.build(from: SummaryBuilder.sampleObservations(), profile: profile, isSample: true)
        let decoding = summary.areas.first { $0.kind == .decoding }
        #expect(decoding?.observed.contains { $0.contains("Made-up names started in about") && $0.contains("Real words") } == true)
    }

    @Test func medianIgnoresOneSlowTry() {
        #expect(SummaryBuilder.median([1000, 1100, 9000]) == 1100)
        #expect(SummaryBuilder.median([1000, 2000]) == 1500)
        #expect(SummaryBuilder.median([]) == nil)
    }
}

/// The screening recommendation at the top of every summary.
struct ReferralTests {
    private let session = UUID()

    private func profile(_ age: Profile.AgeBand = .sevenToEight, familyHistory: Profile.Answer? = nil) -> Profile {
        var profile = Profile(nickname: "Robin")
        profile.ageBand = age
        profile.familyHistory = familyHistory
        profile.visionHearingChecked = .yes
        return profile
    }

    private func letters(firstTry: Int, of total: Int) -> [ItemObservation] {
        (0..<total).map { index in
            var o = ItemObservation(sessionID: session, activity: .soundSprings, itemID: "ss-\(index)", target: "w\(index)")
            o.firstTry = index < firstTry
            o.tries = index < firstTry ? 1 : 2
            o.responseMs = 2000
            return o
        }
    }

    private func spoken(_ activity: Activity, right: Int, of total: Int, tag: String = "single") -> [ItemObservation] {
        (0..<total).map { index in
            var o = ItemObservation(sessionID: session, activity: activity, itemID: "\(activity.rawValue)-\(index)", target: "w\(index)")
            o.itemTag = tag
            o.onsetMs = 1500
            o.wordCheck = index < right ? .matched : .unclear
            o.grownUpMark = index < right ? nil : .neededHelp
            return o
        }
    }

    @Test func smoothPlayNeedsNoFollowUp() {
        let observations = letters(firstTry: 8, of: 8) + spoken(.echoCave, right: 6, of: 6)
        let referral = SummaryBuilder.build(from: observations, profile: profile()).referral
        #expect(referral.level == .noFollowUp)
        #expect(referral.whoToSee.isEmpty)
    }

    @Test func twoTrickyAreasRecommendASpecialist() {
        let observations = letters(firstTry: 2, of: 8) + spoken(.echoCave, right: 1, of: 6)
        let referral = SummaryBuilder.build(from: observations, profile: profile()).referral
        #expect(referral.level == .seeSpecialist)
        #expect(referral.whoToSee.contains { $0.contains("pediatrician") })
        #expect(referral.whoToSee.contains { $0.contains("dyslexia") })
    }

    @Test func oneTrickyAreaIsACheckInUnlessItRunsInTheFamily() {
        let observations = letters(firstTry: 8, of: 8) + spoken(.echoCave, right: 1, of: 6)
        #expect(SummaryBuilder.build(from: observations, profile: profile()).referral.level == .checkIn)
        #expect(SummaryBuilder.build(from: observations, profile: profile(familyHistory: .yes)).referral.level == .seeSpecialist)
    }

    @Test func wordReadingIsNotCountedForFiveAndSixYearOlds() {
        let observations = letters(firstTry: 8, of: 8) + spoken(.echoCave, right: 6, of: 6) + spoken(.wordWoods, right: 0, of: 6, tag: "short")
        #expect(SummaryBuilder.build(from: observations, profile: profile(.fiveToSix)).referral.level == .noFollowUp)
        #expect(SummaryBuilder.build(from: observations, profile: profile(.sevenToEight)).referral.level == .checkIn)
    }

    @Test func oneIslandIsNotEnoughToRecommendAnything() {
        let referral = SummaryBuilder.build(from: letters(firstTry: 1, of: 8), profile: profile()).referral
        #expect(referral.level == .notEnough)
    }

    @Test func trickySoundPuzzlesSuggestAHearingCheckWhenHearingWasNotChecked() {
        var noHearingCheck = profile()
        noHearingCheck.visionHearingChecked = .notSure
        let observations = letters(firstTry: 2, of: 8) + spoken(.echoCave, right: 1, of: 6)
        let referral = SummaryBuilder.build(from: observations, profile: noHearingCheck).referral
        #expect(referral.whoToSee.contains { $0.contains("hearing check") })
    }
}
