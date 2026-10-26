import Foundation
import Testing
@testable import ReadRight

/// Feeds the detector made-up loudness readings, 10 ms apart, so we can check its timing exactly.
struct VoiceOnsetDetectorTests {
    /// Each segment is (how many seconds, what loudness in dB).
    private func run(_ detector: inout VoiceOnsetDetector, _ segments: [(TimeInterval, Float)]) -> [VoiceOnsetDetector.Event] {
        var events: [VoiceOnsetDetector.Event] = []
        var step = 0
        for (duration, level) in segments {
            let steps = Int((duration / 0.01).rounded())
            for _ in 0..<steps {
                events += detector.process(time: Double(step) * 0.01, levelDB: level)
                step += 1
            }
        }
        return events
    }

    private func onset(in events: [VoiceOnsetDetector.Event]) -> TimeInterval? {
        for case .onset(let at) in events { return at }
        return nil
    }

    @Test func findsTheStartOfAVoiceAfterQuiet() {
        var detector = VoiceOnsetDetector()
        let events = run(&detector, [(1.0, -60), (0.5, -30)])
        #expect(events.first == .calibrated(noiseFloorDB: -60))
        #expect(abs((onset(in: events) ?? 0) - 1.0) < 0.001)
    }

    @Test func ignoresAShortClick() {
        var detector = VoiceOnsetDetector()
        let events = run(&detector, [(0.5, -60), (0.03, -20), (0.5, -60), (0.3, -30)])
        let at = onset(in: events)
        #expect(at != nil)
        #expect(abs((at ?? 0) - 1.03) < 0.001)
    }

    @Test func quietRoomStillNeedsARealVoice() {
        // Floor -85 dB → threshold is the absolute minimum, -50 dB, not -70 dB.
        var detector = VoiceOnsetDetector()
        let events = run(&detector, [(0.5, -85), (0.5, -60), (0.3, -40)])
        #expect(detector.thresholdDB == -50)
        #expect(abs((onset(in: events) ?? 0) - 1.0) < 0.001)
    }

    @Test func finishesAfterSilence() {
        var detector = VoiceOnsetDetector(settings: .init(endSilenceDuration: 1.0))
        let events = run(&detector, [(0.5, -60), (0.8, -30), (1.5, -60)])
        let finished = events.compactMap { event -> (TimeInterval, TimeInterval)? in
            if case .finished(let onset, let last) = event { return (onset, last) }
            return nil
        }
        #expect(finished.count == 1)
        #expect(abs((finished.first?.0 ?? 0) - 0.5) < 0.001)
        #expect(abs((finished.first?.1 ?? 0) - 1.29) < 0.001)
    }

    @Test func aShortPauseInsideSpeechDoesNotFinish() {
        var detector = VoiceOnsetDetector(settings: .init(endSilenceDuration: 1.0))
        let events = run(&detector, [(0.5, -60), (0.4, -30), (0.5, -60), (0.4, -30), (0.3, -60)])
        #expect(!events.contains { if case .finished = $0 { true } else { false } })
        #expect(abs((detector.lastVoiceTime ?? 0) - 1.79) < 0.001)
    }

    @Test func ignoresSoundBeforeTheLightTurnsGreen() {
        // Talking at 0.7 s while the light is still amber doesn't count. Reading starts at 1.2 s.
        var detector = VoiceOnsetDetector()
        detector.listenFrom = 1.0
        let events = run(&detector, [(0.7, -60), (0.2, -30), (0.3, -60), (0.3, -30)])
        #expect(abs((onset(in: events) ?? 0) - 1.2) < 0.001)
    }

    @Test func talkingThroughTheGreenLightIsNotAZeroReactionTime() {
        // The child is already talking when the light turns green at 1.0 s, pauses, then reads at 1.6 s.
        var detector = VoiceOnsetDetector()
        detector.listenFrom = 1.0
        let events = run(&detector, [(0.8, -60), (0.5, -30), (0.3, -60), (0.3, -30)])
        #expect(abs((onset(in: events) ?? 0) - 1.6) < 0.001)
    }

    @Test func aChildTalkingDuringCalibrationDoesNotHideTheirVoice() {
        // Half the amber light is quiet, half is talking. The floor stays at the quiet room.
        var detector = VoiceOnsetDetector()
        let events = run(&detector, [(0.3, -60), (0.3, -25), (0.4, -60), (0.3, -28)])
        #expect(detector.noiseFloorDB == -60)
        #expect(abs((onset(in: events) ?? 0) - 1.0) < 0.001)
    }

    @Test func noVoiceMeansNoOnset() {
        var detector = VoiceOnsetDetector()
        let events = run(&detector, [(3.0, -55)])
        #expect(onset(in: events) == nil)
        #expect(detector.onsetTime == nil)
    }

    @Test func rapidNamingWaitsLongerBeforeFinishing() {
        var detector = VoiceOnsetDetector(settings: .rapidNaming)
        // Two seconds of quiet between colors is still "naming", not "done".
        let events = run(&detector, [(0.5, -60), (0.5, -30), (2.0, -60), (0.5, -30), (3.5, -60)])
        let finished = events.compactMap { event -> TimeInterval? in
            if case .finished(_, let last) = event { return last }
            return nil
        }
        #expect(finished.count == 1)
        #expect(abs((finished.first ?? 0) - 3.49) < 0.001)
    }
}
