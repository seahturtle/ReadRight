import Foundation
import Observation
import UIKit

/// The grown-up's setup: a nickname, an age group, privacy choices, and optional background.
/// Saved in the same protected folder as the observations, and erased with them.
struct Profile: Codable, Equatable {
    enum AgeBand: String, Codable, CaseIterable {
        case fiveToSix = "5-6"
        case sevenToEight = "7-8"

        var label: String {
            switch self {
            case .fiveToSix: "5 to 6 years"
            case .sevenToEight: "7 to 8 years"
            }
        }
    }

    enum Answer: String, Codable, CaseIterable {
        case yes, no, notSure

        var label: String {
            switch self {
            case .yes: "Yes"
            case .no: "No"
            case .notSure: "Not sure"
            }
        }
    }

    var nickname = "Explorer"
    var ageBand = AgeBand.fiveToSix
    var setupDone = false

    // Choices. Everything starts off until a grown-up turns it on.
    var keepNotebook = false
    var listenToReading = false

    // Optional background. Research links these to reading differences, or they change what play results mean.
    var familyHistory: Answer?
    var speechDelay: Answer?
    var visionHearingChecked: Answer?
    var speaksOtherLanguages: Answer?

    init(nickname: String = "Explorer") {
        self.nickname = nickname
    }

    /// Every field is optional when loading, so a file saved by an older version of the app still loads
    /// after someone adds a new field.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? "Explorer"
        ageBand = try c.decodeIfPresent(AgeBand.self, forKey: .ageBand) ?? .fiveToSix
        setupDone = try c.decodeIfPresent(Bool.self, forKey: .setupDone) ?? false
        keepNotebook = try c.decodeIfPresent(Bool.self, forKey: .keepNotebook) ?? false
        listenToReading = try c.decodeIfPresent(Bool.self, forKey: .listenToReading) ?? false
        familyHistory = try c.decodeIfPresent(Answer.self, forKey: .familyHistory)
        speechDelay = try c.decodeIfPresent(Answer.self, forKey: .speechDelay)
        visionHearingChecked = try c.decodeIfPresent(Answer.self, forKey: .visionHearingChecked)
        speaksOtherLanguages = try c.decodeIfPresent(Answer.self, forKey: .speaksOtherLanguages)
    }
}

@MainActor
@Observable
final class ProfileStore {
    var profile: Profile { didSet { save() } }

    @ObservationIgnored private let fileURL: URL
    /// False while the file exists but couldn't be read (the phone was locked when the app launched).
    /// Nothing is saved over it until it has been read.
    @ObservationIgnored private var canSave = true
    @ObservationIgnored private var unlockObserver: NSObjectProtocol?

    init(fileURL: URL? = nil) {
        let url = fileURL ?? URL.applicationSupportDirectory
            .appending(path: "ReadRight", directoryHint: .isDirectory)
            .appending(path: "profile.json")
        self.fileURL = url
        let (loaded, readable) = Self.load(url)
        profile = loaded ?? Profile()
        canSave = readable
        unlockObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.retryLoadIfNeeded() }
        }
    }

    func reset() {
        canSave = false
        profile = Profile()
        try? FileManager.default.removeItem(at: fileURL)
        canSave = true
    }

    /// (profile, true) when loaded; (nil, true) when there's no file or it's corrupt; (nil, false) when unreadable.
    private static func load(_ url: URL) -> (Profile?, Bool) {
        guard FileManager.default.fileExists(atPath: url.path()) else { return (nil, true) }
        guard let data = try? Data(contentsOf: url) else { return (nil, false) }
        return ((try? JSONDecoder().decode(Profile.self, from: data)), true)
    }

    private func retryLoadIfNeeded() {
        guard !canSave else { return }
        let (loaded, readable) = Self.load(fileURL)
        guard readable else { return }
        canSave = true
        if let loaded { profile = loaded }
    }

    private func save() {
        guard canSave else { return }
        do {
            var folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            try JSONEncoder().encode(profile).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("ReadRight could not save the profile: \(error.localizedDescription)")
        }
    }
}
