import Foundation

enum Activity: String, Codable, CaseIterable, Identifiable {
    case soundSprings, echoCave, wordWoods, fireflyDash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soundSprings: "Sound Springs"
        case .echoCave: "Echo Cave"
        case .wordWoods: "Word Woods"
        case .fireflyDash: "Firefly Dash"
        }
    }

    var subtitle: String {
        switch self {
        case .soundSprings: "Match sounds to letters"
        case .echoCave: "Play with the sounds in words"
        case .wordWoods: "Read little words out loud"
        case .fireflyDash: "Name the pictures, fast!"
        }
    }
}

/// What the on-device recognizer concluded about a word read aloud.
/// A mismatch is "unclear", never "wrong": speech recognizers are unreliable on young children's voices.
enum WordCheck: String, Codable {
    case matched
    case unclear
    /// No recognizer on this device, or it failed. Only voice timing was measured.
    case unavailable
    /// Pip didn't hear any voice before the time limit.
    case noResponse
}

/// A grown-up's own judgment. It overrides the automatic word check.
enum GrownUpMark: String, Codable {
    case readIt, neededHelp, skipped
}

/// Grown-up's answer after Firefly Dash: did the child name every firefly?
enum NamedAll: String, Codable {
    case all, most, few
}

/// How a time was measured.
enum TimingSource: String, Codable {
    /// From the microphone: the moment a voice started or stopped.
    case voice
    /// A grown-up tapped Go and Done.
    case grownUpTaps
}

/// One observation from one item in one game.
///
/// Only numbers and short labels are stored. Never audio, never transcripts.
///
/// If you add a field, make it Optional (`var something: Int?`). Then files saved by older
/// versions of the app still load.
struct ItemObservation: Codable, Identifiable, Hashable {
    var id = UUID()
    var sessionID: UUID
    var activity: Activity
    var itemID: String
    var target: String
    var recordedAt = Date()
    var itemTag: String?

    // Sound Springs
    var firstTry: Bool?
    var tries: Int?
    /// Time from the end of the spoken word to the child's first tap.
    var responseMs: Int?
    /// The first wrong letter the child picked, if any.
    var distractorChosen: String?
    /// What kind of mix-up that letter was: `mirrorImage`, `soundAlike` or `other` (see `ItemBank`).
    var distractorKind: String?
    var hintShown: Bool?
    var replays: Int?

    // Word Woods and Firefly Dash
    /// Time from the word (or grid) appearing to the child's first sound.
    var onsetMs: Int?
    var wordCheck: WordCheck?
    var grownUpMark: GrownUpMark?
    /// Firefly Dash: time from the first color spoken to the last.
    var namingMs: Int?
    var namedAll: NamedAll?
    var timing: TimingSource?

    init(sessionID: UUID, activity: Activity, itemID: String, target: String) {
        self.sessionID = sessionID
        self.activity = activity
        self.itemID = itemID
        self.target = target
    }
}
