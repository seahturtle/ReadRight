import Foundation

/// Every line Pip says out loud, in one place. The Voice Studio lists these so a person can record
/// them in a warm, real voice. Any line without a recording uses the iPhone's voice.
enum PipLines {
    struct Line: Identifiable, Hashable {
        let group: String
        let text: String
        var id: String { text }
    }

    // MARK: Sound Springs

    static let soundSpringsIntro = "Hi, I'm Pip! Listen to the word, then tap the letter it starts with."
    static let soundSpringsCheers = ["Hop! You lit a firefly.", "Nice listening. Off we go!", "You did it. Another firefly!", "Lovely thinking. Hop on!"]
    static let soundSpringsWobbles = ["Almost! Let's listen again.", "That stone wobbled. Try another one.", "Good try. Have another look."]
    static let soundSpringsDone = "Sound Springs visited! Every firefly counts."

    static func soundSpringsHint(_ item: LetterItem) -> String {
        "\(item.word) starts with \(item.answer)."
    }

    // MARK: Echo Cave

    static let echoCaveIntro = "In Echo Cave, the echo forgets the first sound of words! If I say meat without its first sound, I get eat. Let's practice first. Wait for the green light, then say what's left."
    static let echoCaveRealStart = "Great practicing! Now let's do some real puzzles."
    static let echoCaveDone = "Echo Cave visited! Those were tricky sound puzzles. Every firefly counts."

    static func echoCavePrompt(_ word: String) -> String {
        "\(word)! Now say \(word), without its first sound."
    }

    static func echoCavePracticeAnswer(_ word: String, _ answer: String) -> String {
        "\(word) without its first sound is \(answer). Nice try!"
    }

    // MARK: Word Woods

    static let wordWoodsIntro = "Let's read some words out loud. Wait for the green light, then read the word to me. Any way you say it is fine!"
    static let wordWoodsDone = "Word Woods visited! You read the whole path. Every firefly counts."

    // MARK: Firefly Dash

    static func fireflyIntro(_ age: Profile.AgeBand) -> String {
        age == .fiveToSix
            ? "My fireflies are carrying pictures. Say the name of each picture out loud, as fast as you can!"
            : "My fireflies are carrying letters. Say the name of each letter out loud, as fast as you can!"
    }

    static let fireflyPractice = "Say these out loud. Start at the arrow."
    static let fireflyReady = "Tap Go. When the light turns green, say every one, row by row. Then tap I'm done."
    static let fireflyDone = "All my fireflies are glowing. Thank you!"

    // MARK: Other

    static let voicePreview = "Hi, I'm Pip! Let's walk through Letterwood together."

    /// Every line for both age groups, for the Voice Studio.
    static var catalog: [Line] {
        var lines: [Line] = []
        func add(_ group: String, _ texts: [String]) {
            for text in texts where !lines.contains(where: { $0.text == text }) {
                lines.append(Line(group: group, text: text))
            }
        }
        add("Hello", [voicePreview, soundSpringsIntro, echoCaveIntro, wordWoodsIntro, fireflyIntro(.fiveToSix), fireflyIntro(.sevenToEight)])
        add("Sound Springs words", ItemBank.soundSprings.map(\.word))
        add("Sound Springs hints", ItemBank.soundSprings.map(soundSpringsHint))
        add("Echo Cave puzzles", Profile.AgeBand.allCases.flatMap { ItemBank.echoCave(for: $0) }.compactMap(\.prompt))
        add("Echo Cave practice answers", ItemBank.echoCavePractice.map { echoCavePracticeAnswer($0.spoken, $0.target) })
        add("Cheers and gentle tries", soundSpringsCheers + soundSpringsWobbles + [echoCaveRealStart])
        add("Firefly Dash", [fireflyPractice, fireflyReady])
        add("Goodbyes", [soundSpringsDone, echoCaveDone, wordWoodsDone, fireflyDone])
        return lines
    }
}
