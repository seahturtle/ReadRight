import Foundation

/// Finds when a child starts and stops speaking, from a stream of loudness readings.
///
/// It doesn't understand words. It only answers: "When did the room get clearly louder
/// than its own background noise, and stay that way long enough to be a voice?"
///
/// 1. **Calibrate.** For the first `calibrationDuration` seconds after the word appears,
///    average the loudness. That's the room's noise floor. Children almost never start
///    reading that quickly.
/// 2. **Threshold.** A voice has to be `marginDB` louder than the floor, and never quieter
///    than `absoluteMinimumDB`, so breathing in a silent room doesn't count as speech.
/// 3. **Onset.** The first moment loudness stays above the threshold for at least
///    `minimumVoiceDuration`. Clicks and taps are shorter than that and get ignored.
///    The onset time is the *start* of that loud stretch.
/// 4. **Finished.** After the onset, the child is done once it has been quiet for
///    `endSilenceDuration`. "Quiet" uses a slightly lower threshold (`releaseDB`) so the
///    soft end of a word still counts as voice.
///
/// This is a plain struct with no audio code in it, so it can be unit tested with made-up numbers.
struct VoiceOnsetDetector {
    struct Settings: Equatable {
        var calibrationDuration: TimeInterval = 0.25
        var marginDB: Float = 15
        var absoluteMinimumDB: Float = -50
        var minimumVoiceDuration: TimeInterval = 0.06
        var releaseDB: Float = 6
        var endSilenceDuration: TimeInterval = 0.8

        /// One word read aloud. The games calibrate while the light is amber ("Get ready"),
        /// before the word appears, so the child is quiet during calibration.
        static let singleWord = Settings(calibrationDuration: 0.6, endSilenceDuration: 0.8)
        /// Naming a grid of colors. Children pause between items, so wait longer before deciding they're done.
        static let rapidNaming = Settings(calibrationDuration: 0.6, endSilenceDuration: 3.0)
    }

    enum Event: Equatable {
        case calibrated(noiseFloorDB: Float)
        case onset(at: TimeInterval)
        case finished(onset: TimeInterval, lastVoice: TimeInterval)
    }

    let settings: Settings
    /// Sound before this time is ignored for onset. Games set it to the moment the word appears
    /// (the light turns green), so noise while the light was amber can't count as reading.
    var listenFrom: TimeInterval = 0
    private(set) var noiseFloorDB: Float?
    private(set) var onsetTime: TimeInterval?
    private(set) var lastVoiceTime: TimeInterval?
    private(set) var isFinished = false

    private var calibrationLevels: [Float] = []
    private var loudStretchStart: TimeInterval?
    /// Onsets only count after at least one quiet moment once listening starts. If a child is already
    /// talking when the light turns green, that isn't a reaction time of zero.
    private var armed = false

    /// Guards against floating-point rounding when comparing durations.
    private let epsilon: TimeInterval = 1e-6

    init(settings: Settings = .singleWord) {
        self.settings = settings
    }

    /// The loudness a voice must reach, once calibration is done.
    var thresholdDB: Float? {
        noiseFloorDB.map { max($0 + settings.marginDB, settings.absoluteMinimumDB) }
    }

    /// Feed one loudness reading. `time` is seconds since the word appeared.
    mutating func process(time: TimeInterval, levelDB: Float) -> [Event] {
        guard !isFinished else { return [] }
        var events: [Event] = []

        if noiseFloorDB == nil {
            if time < settings.calibrationDuration {
                calibrationLevels.append(levelDB)
                return []
            }
            // The quietest fifth of the room, not the average, so a child talking during amber
            // can't make the room seem loud and hide their voice.
            let sorted = calibrationLevels.sorted()
            let floor = sorted.isEmpty ? levelDB : sorted[sorted.count / 5]
            noiseFloorDB = floor
            events.append(.calibrated(noiseFloorDB: floor))
        }
        guard let threshold = thresholdDB else { return events }
        guard onsetTime != nil || time >= listenFrom else { return events }

        if let onset = onsetTime {
            if levelDB >= threshold - settings.releaseDB {
                lastVoiceTime = time
            } else if let last = lastVoiceTime, time - last + epsilon >= settings.endSilenceDuration {
                isFinished = true
                events.append(.finished(onset: onset, lastVoice: last))
            }
        } else if !armed {
            if levelDB < threshold { armed = true }
        } else if levelDB >= threshold {
            let start = loudStretchStart ?? time
            loudStretchStart = start
            if time - start + epsilon >= settings.minimumVoiceDuration {
                onsetTime = start
                lastVoiceTime = time
                events.append(.onset(at: start))
            }
        } else {
            loudStretchStart = nil
        }
        return events
    }
}
