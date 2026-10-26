import Foundation
import Testing
@testable import ReadRight

struct AudioLevelTests {
    @Test func silenceIsTheFloor() {
        #expect(AudioLevel.rmsDB([Float](repeating: 0, count: 480)) == AudioLevel.minimumDB)
        #expect(AudioLevel.rmsDB([]) == AudioLevel.minimumDB)
    }

    @Test func fullScaleSineIsAboutMinusThreeDB() {
        let samples = (0..<4800).map { Float(sin(2 * Double.pi * Double($0) / 100)) }
        #expect(abs(AudioLevel.rmsDB(samples) - (-3.01)) < 0.05)
    }

    @Test func halfAmplitudeIsAboutMinusSixDB() {
        #expect(abs(AudioLevel.rmsDB([Float](repeating: 0.5, count: 480)) - (-6.02)) < 0.05)
    }
}

struct SpeechMatchingTests {
    @Test func matchesWholeWordsOnly() {
        #expect(SpeechChecker.containsWord(in: "Frog", from: ["frog"]))
        #expect(SpeechChecker.containsWord(in: "the frog.", from: ["frog"]))
        #expect(!SpeechChecker.containsWord(in: "frogs", from: ["frog"]))
        #expect(!SpeechChecker.containsWord(in: "fog", from: ["frog"]))
    }

    @Test func acceptsHomophones() {
        #expect(SpeechChecker.containsWord(in: "Son", from: ["sun", "son"]))
    }
}

struct ItemBankTests {
    @Test func soundSpringsChoicesAreFair() {
        for item in ItemBank.soundSprings {
            #expect(item.word.hasPrefix(item.answer), "\(item.word) should start with \(item.answer)")
            #expect(Set(item.choices).count == 4, "\(item.word) needs 4 different letters")
            #expect(!item.distractors.contains { ["c", "k", "s"].contains($0.letter) && (item.answer == "c" || item.answer == "s") }, "\(item.word): no letter that can spell the same sound")
            #expect(!item.distractors.map(\.letter).contains(item.answer))
        }
    }

    @Test(arguments: Profile.AgeBand.allCases)
    func wordWoodsMixesRealAndMadeUpWords(age: Profile.AgeBand) {
        let items = ItemBank.wordWoods(for: age)
        #expect(Set(items.map(\.id)).count == items.count)
        #expect(items.filter { $0.tag == .madeUp }.count >= 2)
        #expect(items.filter { $0.tag == .short || $0.tag == .blend }.count >= 6)
        // The recognizer would "correct" made-up words, so it must be off for them, and on for real words.
        for item in items {
            #expect(item.checkWithRecognizer == (item.tag != .madeUp), "\(item.target)")
            #expect(item.shown == item.target)
        }
    }

    @Test func echoCaveStartsWithPracticeThatIsNeverRecorded() {
        #expect(ItemBank.echoCavePractice.count == 2)
        #expect(ItemBank.echoCavePractice.allSatisfy { $0.isPractice })
        for age in Profile.AgeBand.allCases {
            #expect(!ItemBank.echoCave(for: age).contains { $0.isPractice })
        }
    }

    @Test func everyLinePipSaysCanBeRecorded() {
        let lines = PipLines.catalog
        #expect(Set(lines.map(\.text)).count == lines.count)
        #expect(Set(lines.map { VoiceClips.key(for: $0.text) }).count == lines.count, "two lines share a recording file")
        #expect(lines.contains { $0.text == "bus" })
        #expect(lines.contains { $0.text == PipLines.echoCavePrompt("snail") })
    }

    @Test(arguments: Profile.AgeBand.allCases)
    func echoCaveAnswersAreTheWordWithoutItsStart(age: Profile.AgeBand) throws {
        for item in ItemBank.echoCave(for: age) {
            let prompt = try #require(item.prompt)
            let spoken = String(prompt.prefix { $0.isLetter })
            #expect(spoken.hasSuffix(item.target) && spoken != item.target, "\(spoken) → \(item.target)")
            #expect(item.checkWithRecognizer)
        }
        #expect(ItemBank.echoCave(for: age).contains { $0.tag == .single })
        #expect(ItemBank.echoCave(for: age).contains { $0.tag == .cluster })
    }

    @Test(arguments: Profile.AgeBand.allCases)
    func fireflyGridIsBalancedWithNoRepeats(age: Profile.AgeBand) {
        let grid = ItemBank.fireflyGrid(for: age)
        #expect(grid.count == 20)
        for item in ItemBank.namingSet(for: age) {
            #expect(grid.filter { $0 == item }.count == 4, "\(item) should appear 4 times")
        }
        #expect(Set(ItemBank.fireflyPractice(for: age)) == Set(ItemBank.namingSet(for: age)))
        // Pictures for 5-6, letters for 7-8, as in standard rapid-naming tests.
        #expect(grid.allSatisfy { $0.isLetter == (age == .sevenToEight) })
        for index in 1..<grid.count {
            #expect(grid[index] != grid[index - 1], "repeat at position \(index)")
        }
    }
}

@MainActor
struct ObservationStoreTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "ReadRightTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "observations.json")
    }

    @Test func savesAndLoads() {
        let file = temporaryFile()
        let store = ObservationStore(fileURL: file)
        store.savesToDisk = true
        var observation = ItemObservation(sessionID: store.sessionID, activity: .wordWoods, itemID: "ww-cat", target: "cat")
        observation.onsetMs = 900
        observation.wordCheck = .matched
        store.add(observation)

        let reopened = ObservationStore(fileURL: file)
        #expect(reopened.observations.count == 1)
        #expect(reopened.observations.first?.onsetMs == 900)
        #expect(reopened.observations.first?.wordCheck == .matched)
    }

    @Test func deletesOldSessionsAfterRetentionPeriod() {
        let file = temporaryFile()
        let store = ObservationStore(fileURL: file)
        store.savesToDisk = true
        var old = ItemObservation(sessionID: UUID(), activity: .soundSprings, itemID: "ss-bat", target: "bat")
        old.recordedAt = Date.now.addingTimeInterval(-100 * 24 * 60 * 60)
        store.add(old)
        store.add(ItemObservation(sessionID: store.sessionID, activity: .soundSprings, itemID: "ss-dog", target: "dog"))

        let reopened = ObservationStore(fileURL: file)
        #expect(reopened.observations.map(\.itemID) == ["ss-dog"])
    }

    @Test func unreadableFileIsSetAsideNotOverwritten() throws {
        let file = temporaryFile()
        let folder = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: file)

        let store = ObservationStore(fileURL: file)
        store.savesToDisk = true
        #expect(store.observations.isEmpty)
        store.add(ItemObservation(sessionID: store.sessionID, activity: .wordWoods, itemID: "ww-cat", target: "cat"))

        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path())
        #expect(names.contains { $0.hasPrefix("observations-unreadable-") })
        #expect(ObservationStore(fileURL: file).observations.count == 1)
    }

    @Test func deleteAllRemovesTheFile() {
        let file = temporaryFile()
        let store = ObservationStore(fileURL: file)
        store.savesToDisk = true
        store.add(ItemObservation(sessionID: store.sessionID, activity: .fireflyDash, itemID: "fd-grid-1", target: "20 colors"))
        store.deleteAll()
        #expect(store.observations.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path()))
    }
}

struct ParentGateTests {
    @Test func problemsUseWordsAndNumbersFromThreeToNine() {
        for _ in 0..<200 {
            let problem = ParentGate.Problem.random()
            #expect((3...9).contains(problem.left) && (3...9).contains(problem.right))
            #expect(!problem.question.contains { $0.isNumber }, "the question must be written in words")
        }
    }

    @Test func checksTheAnswer() {
        let problem = ParentGate.Problem(left: 7, right: 8)
        #expect(problem.question == "What is seven times eight?")
        #expect(problem.isAnswered(by: "56"))
        #expect(problem.isAnswered(by: " 56 "))
        #expect(!problem.isAnswered(by: "54"))
        #expect(!problem.isAnswered(by: "fifty-six"))
    }

    @Test func aWrongAnswerGetsADifferentProblem() {
        let first = ParentGate.Problem(left: 4, right: 6)
        for _ in 0..<50 {
            #expect(ParentGate.Problem.random(avoiding: first) != first)
        }
    }
}
