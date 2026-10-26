import Foundation
import Observation
import UIKit

/// Keeps every observation in one JSON file in Application Support.
///
/// Privacy choices, all on purpose:
/// - The file uses complete file protection, so it's encrypted whenever the iPhone is locked.
/// - The folder is excluded from iCloud and computer backups.
/// - The app never sends this file anywhere. Sharing happens only if a grown-up exports a summary.
/// - Observations older than `retentionDays` are deleted when the app opens.
///
/// It also never saves over a file it couldn't read, so saved history isn't lost by accident.
@MainActor
@Observable
final class ObservationStore {
    static let retentionDays = 90

    private(set) var observations: [ItemObservation] = []

    /// A new session starts each time the app launches.
    let sessionID = UUID()

    /// The grown-up's "Keep Pip's notebook" choice. Off (the default): observations live only in memory
    /// until the app closes. Turning it off never deletes anything by itself; see `forgetSavedFile()`.
    var savesToDisk = false {
        didSet {
            if savesToDisk, !oldValue { save() }
        }
    }

    /// Called only when a grown-up turns the notebook off.
    func forgetSavedFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private let fileURL: URL
    /// False while the file exists but couldn't be read yet (the phone was locked when the app launched).
    @ObservationIgnored private var canSave = true
    @ObservationIgnored private var unlockObserver: NSObjectProtocol?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()
        deleteExpired()
        unlockObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.retryLoadIfNeeded() }
        }
    }

    func add(_ observation: ItemObservation) {
        retryLoadIfNeeded()
        observations.append(observation)
        save()
    }

    func deleteAll() {
        observations.removeAll()
        // Removes the whole folder, including any unreadable file that was set aside.
        try? FileManager.default.removeItem(at: folderURL)
        canSave = true
    }

    private var folderURL: URL { fileURL.deletingLastPathComponent() }

    private static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "ReadRight", directoryHint: .isDirectory)
            .appending(path: "observations.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            observations = try Self.decoder.decode([ItemObservation].self, from: data)
            canSave = true
        } catch is DecodingError {
            // The format changed (for example, someone added a non-optional field to ItemObservation).
            // Keep the old file under another name instead of overwriting it, and start fresh.
            let stamp = Int(Date.now.timeIntervalSince1970)
            try? FileManager.default.moveItem(at: fileURL, to: folderURL.appending(path: "observations-unreadable-\(stamp).json"))
            observations = []
            canSave = true
        } catch {
            // Most likely the phone is locked and the file is still encrypted. Don't save over it.
            // Try again when the phone unlocks.
            canSave = false
        }
    }

    /// Loads the file now that it's readable, then adds anything recorded in the meantime.
    private func retryLoadIfNeeded() {
        guard !canSave else { return }
        let unsaved = observations
        observations = []
        load()
        observations += unsaved
        if canSave, !unsaved.isEmpty { save() }
    }

    private func deleteExpired() {
        let cutoff = Date.now.addingTimeInterval(-Double(Self.retentionDays) * 24 * 60 * 60)
        let kept = observations.filter { $0.recordedAt >= cutoff }
        if kept.count != observations.count {
            observations = kept
            save()
        }
    }

    private func save() {
        guard canSave, savesToDisk else { return }
        do {
            var folder = folderURL
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)

            let data = try Self.encoder.encode(observations)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            // Log the failure only. Never log the observations themselves.
            print("ReadRight could not save observations: \(error.localizedDescription)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
