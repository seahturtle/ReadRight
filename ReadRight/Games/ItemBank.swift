import Foundation

/// Every word, letter and picture the games use, in one place so they're easy to review and change.
/// Have a teacher or reading specialist look over these lists before using them with families.
enum ItemBank {
    // MARK: Sound Springs: letter–sound knowledge

    /// Four stones, so a lucky guess is 1 in 4 instead of 1 in 3.
    /// Distractors are chosen on purpose, so a repeated mix-up has a name the family summary can use:
    /// mirror-image letters (b/d, p/q, m/w) and sound-alike letters (b/p, d/t, s/z, f/v, c/g, m/n).
    /// Letters that can spell the same first sound (c and k for "cup", c and s for "sun") are never used.
    /// The picture (an SF Symbol, so it draws on every iPhone) helps a child know which word they heard.
    /// The word itself is never written, because that would show the answer.
    static let soundSprings: [LetterItem] = [
        LetterItem(id: "ss-bus", word: "bus", picture: "bus.fill", answer: "b", distractors: [.init("d", .mirrorImage), .init("p", .soundAlike), .init("h", .other)]),
        LetterItem(id: "ss-dog", word: "dog", picture: "dog.fill", answer: "d", distractors: [.init("b", .mirrorImage), .init("t", .soundAlike), .init("g", .other)]),
        LetterItem(id: "ss-sun", word: "sun", picture: "sun.max.fill", answer: "s", distractors: [.init("z", .soundAlike), .init("t", .other), .init("x", .other)]),
        LetterItem(id: "ss-pencil", word: "pencil", picture: "pencil", answer: "p", distractors: [.init("q", .mirrorImage), .init("b", .soundAlike), .init("d", .other)]),
        LetterItem(id: "ss-moon", word: "moon", picture: "moon.fill", answer: "m", distractors: [.init("w", .mirrorImage), .init("n", .soundAlike), .init("u", .other)]),
        LetterItem(id: "ss-fish", word: "fish", picture: "fish.fill", answer: "f", distractors: [.init("v", .soundAlike), .init("t", .other), .init("l", .other)]),
        LetterItem(id: "ss-tree", word: "tree", picture: "tree.fill", answer: "t", distractors: [.init("d", .soundAlike), .init("f", .other), .init("k", .other)]),
        LetterItem(id: "ss-cup", word: "cup", picture: "cup.and.saucer.fill", answer: "c", distractors: [.init("g", .soundAlike), .init("o", .other), .init("e", .other)]),
    ]

    // MARK: Word Woods: real word reading and made-up word decoding

    /// Real words and made-up "creature names" are mixed, so tiredness doesn't fall on one kind.
    /// Made-up words can't be memorized, so they show whether a child can sound out letters. Research
    /// treats this as one of the clearest signs to watch, so there are several of them.
    /// The recognizer is turned off for them (it would "correct" zib to zip); a grown-up marks them instead.
    static func wordWoods(for age: Profile.AgeBand) -> [SpeakItem] {
        switch age {
        case .fiveToSix:
            [
                .read("ww-cat", "cat", tag: .short),
                .madeUp("ww-zib", "zib", creature: 0),
                .read("ww-sun", "sun", tag: .short, alsoAccept: ["son"]),
                .read("ww-pig", "pig", tag: .short),
                .madeUp("ww-fep", "fep", creature: 1),
                .read("ww-frog", "frog", tag: .blend),
                .madeUp("ww-vog", "vog", creature: 2),
                .read("ww-bed", "bed", tag: .short),
                .read("ww-stop", "stop", tag: .blend),
                .madeUp("ww-lut", "lut", creature: 3),
            ]
        case .sevenToEight:
            [
                .read("ww-sun", "sun", tag: .short, alsoAccept: ["son"]),
                .madeUp("ww-zib", "zib", creature: 0),
                .read("ww-frog", "frog", tag: .blend),
                .read("ww-crab", "crab", tag: .blend),
                .madeUp("ww-vog", "vog", creature: 1),
                .read("ww-flag", "flag", tag: .blend),
                .madeUp("ww-blim", "blim", creature: 2),
                .read("ww-map", "map", tag: .short),
                .madeUp("ww-snup", "snup", creature: 3),
                .read("ww-stop", "stop", tag: .blend),
                .madeUp("ww-frim", "frim", creature: 0),
            ]
        }
    }

    // MARK: Echo Cave: phonemic awareness (elision)

    /// Two practice puzzles first. Pip says the answer afterwards, like the practice items in
    /// professional tests, so children understand the game before anything is recorded.
    static let echoCavePractice: [SpeakItem] = [
        .echo("ec-practice-meat", say: "meat", answer: "eat", tag: .single, practice: true),
        .echo("ec-practice-pink", say: "pink", answer: "ink", tag: .single, practice: true),
    ]

    /// "Say snail without its first sound" → "nail". Every answer is a real word, so the on-device
    /// recognizer can check it. Taking a sound off the front of a blend (snail, stop) is harder than
    /// off a single sound (cat), so the summary compares the two kinds.
    static func echoCave(for age: Profile.AgeBand) -> [SpeakItem] {
        let all: [SpeakItem] = [
            .echo("ec-cat", say: "cat", answer: "at", tag: .single),
            .echo("ec-farm", say: "farm", answer: "arm", tag: .single),
            .echo("ec-snail", say: "snail", answer: "nail", tag: .cluster),
            .echo("ec-seat", say: "seat", answer: "eat", tag: .single),
            .echo("ec-stop", say: "stop", answer: "top", tag: .cluster),
            .echo("ec-bus", say: "bus", answer: "us", tag: .single),
            .echo("ec-train", say: "train", answer: "rain", tag: .cluster, alsoAccept: ["reign", "rein"]),
            .echo("ec-plate", say: "plate", answer: "late", tag: .cluster),
        ]
        return age == .fiveToSix ? Array(all.prefix(6)) : all
    }

    // MARK: Firefly Dash: rapid automatized naming

    /// Pictures for younger children, letters for older ones, as in standard rapid-naming tests.
    /// Pictures and letters replaced colors, which aren't fair to color-blind children.
    static func namingSet(for age: Profile.AgeBand) -> [NamingItem] {
        age == .fiveToSix ? [.star, .heart, .car, .fish, .tree] : [.o, .a, .s, .d, .p]
    }

    static func fireflyPractice(for age: Profile.AgeBand) -> [NamingItem] {
        let set = namingSet(for: age)
        return [1, 3, 0, 4, 2].map { set[$0] }
    }

    /// 4 rows of 5, read left to right. Each item appears 4 times, and the same item never appears
    /// twice in a row, including from the end of one row to the start of the next.
    static func fireflyGrid(for age: Profile.AgeBand) -> [NamingItem] {
        let set = namingSet(for: age)
        let pattern = [
            0, 1, 2, 3, 4,
            2, 4, 0, 1, 3,
            0, 3, 4, 2, 1,
            4, 2, 3, 0, 1,
        ]
        return pattern.map { set[$0] }
    }

    static let fireflyColumns = 5

    static func letterItem(id: String) -> LetterItem? {
        soundSprings.first { $0.id == id }
    }
}

struct LetterItem: Identifiable, Hashable {
    enum DistractorKind: String, Codable {
        case mirrorImage, soundAlike, other

        var label: String {
            switch self {
            case .mirrorImage: "mirror-image letter"
            case .soundAlike: "sound-alike letter"
            case .other: "different letter"
            }
        }
    }

    struct Distractor: Hashable {
        let letter: String
        let kind: DistractorKind

        init(_ letter: String, _ kind: DistractorKind) {
            self.letter = letter
            self.kind = kind
        }
    }

    let id: String
    let word: String
    let picture: String
    let answer: String
    let distractors: [Distractor]

    var choices: [String] { [answer] + distractors.map(\.letter) }

    func kind(of letter: String) -> DistractorKind? {
        distractors.first { $0.letter == letter }?.kind
    }
}

/// One thing a child says out loud: a word to read (Word Woods) or an answer to a sound puzzle (Echo Cave).
struct SpeakItem: Identifiable, Hashable {
    enum Tag: String, Codable {
        /// Word Woods: a short real word like "cat".
        case short
        /// Word Woods: a real word that starts with two consonants, like "frog".
        case blend
        /// Word Woods: a made-up creature name like "zib".
        case madeUp
        /// Echo Cave: take off one first sound (cat → at).
        case single
        /// Echo Cave: take the first sound off a blend (snail → nail).
        case cluster
    }

    let id: String
    /// The word we hope to hear.
    let target: String
    let tag: Tag
    /// Other spellings a recognizer may write for the same spoken word (homophones like sun/son).
    var alsoAccept: [String] = []
    /// Word Woods: the word shown on the stone.
    var shown: String?
    /// Echo Cave: the word Pip says, and the puzzle Pip asks before the light turns green.
    var spoken = ""
    var prompt: String?
    /// Off for made-up words, which speech recognizers can't judge.
    var checkWithRecognizer = true
    /// Made-up words appear as one of Pip's friends.
    var creature: Int?
    /// Practice items teach the game. Pip says the answer afterwards, and nothing is recorded.
    var isPractice = false

    static func read(_ id: String, _ word: String, tag: Tag, alsoAccept: [String] = []) -> SpeakItem {
        SpeakItem(id: id, target: word, tag: tag, alsoAccept: alsoAccept, shown: word)
    }

    static func madeUp(_ id: String, _ word: String, creature: Int) -> SpeakItem {
        SpeakItem(id: id, target: word, tag: .madeUp, shown: word, checkWithRecognizer: false, creature: creature)
    }

    static func echo(_ id: String, say word: String, answer: String, tag: Tag, alsoAccept: [String] = [], practice: Bool = false) -> SpeakItem {
        SpeakItem(id: id, target: answer, tag: tag, alsoAccept: alsoAccept, spoken: word, prompt: PipLines.echoCavePrompt(word), isPractice: practice)
    }
}

/// What a firefly carries in Firefly Dash: a picture (5–6) or a letter (7–8).
enum NamingItem: String, CaseIterable, Codable {
    case star, heart, car, fish, tree
    case o, a, s, d, p

    /// The SF Symbol for pictures. Letters are drawn as text.
    var symbol: String? {
        switch self {
        case .star: "star.fill"
        case .heart: "heart.fill"
        case .car: "car.fill"
        case .fish: "fish.fill"
        case .tree: "tree.fill"
        default: nil
        }
    }

    var isLetter: Bool { symbol == nil }
}
