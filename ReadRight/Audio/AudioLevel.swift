import Accelerate

/// Loudness math for the voice-onset detector.
enum AudioLevel {
    /// The quietest level we report, so `log10(0)` never happens.
    static let minimumDB: Float = -100

    /// Root-mean-square loudness of some samples, in decibels relative to full scale (dBFS).
    ///
    /// 0 dB is the loudest a microphone can report. A full-scale sine wave is about -3 dB,
    /// talking near an iPhone is roughly -35 to -20 dB, and a quiet room is about -60 to -50 dB.
    static func rmsDB(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return minimumDB }
        let rms = vDSP.rootMeanSquare(samples)
        guard rms > 0 else { return minimumDB }
        return max(minimumDB, 20 * log10(rms))
    }

    static func rmsDB(_ samples: [Float]) -> Float {
        samples.withUnsafeBufferPointer { rmsDB($0) }
    }
}
