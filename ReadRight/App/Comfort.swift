import Foundation
import Observation

/// Comfort settings, from the prototype's "Comfort settings" menu. Anyone can change these.
@MainActor
@Observable
final class Comfort {
    var largerText: Bool { didSet { defaults.set(largerText, forKey: Keys.largerText) } }
    /// No hopping, bobbing or pulsing.
    var calmMotion: Bool { didSet { defaults.set(calmMotion, forKey: Keys.calmMotion) } }
    /// Pip reads instructions and cheers out loud. Words the games depend on are always spoken.
    var speakPrompts: Bool {
        didSet {
            defaults.set(speakPrompts, forKey: Keys.speakPrompts)
            Speaker.shared.promptsEnabled = speakPrompts
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        largerText = defaults.bool(forKey: Keys.largerText)
        calmMotion = defaults.bool(forKey: Keys.calmMotion)
        speakPrompts = defaults.object(forKey: Keys.speakPrompts) as? Bool ?? true
        Speaker.shared.promptsEnabled = speakPrompts
    }

    private enum Keys {
        static let largerText = "comfort.largerText"
        static let calmMotion = "comfort.calmMotion"
        static let speakPrompts = "comfort.speakPrompts"
    }
}
