import SwiftUI

/// A loudness bar from -80 dB (silent) to 0 dB (loudest), with markers for the
/// room's noise floor (gray) and the voice threshold (orange).
struct LevelMeter: View {
    var levelDB: Float
    var floorDB: Float?
    var thresholdDB: Float?

    private let range: ClosedRange<Float> = -80...0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(isVoice ? Color.green : Color.blue)
                    .frame(width: width * fraction(levelDB))
                if let floorDB { marker(at: width * fraction(floorDB), color: .gray) }
                if let thresholdDB { marker(at: width * fraction(thresholdDB), color: .orange) }
            }
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityLabel("Loudness \(Int(levelDB)) decibels")
    }

    private var isVoice: Bool {
        guard let thresholdDB else { return false }
        return levelDB >= thresholdDB
    }

    private func fraction(_ db: Float) -> CGFloat {
        let clamped = min(max(db, range.lowerBound), range.upperBound)
        return CGFloat((clamped - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private func marker(at x: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 3)
            .offset(x: max(0, x - 1.5))
    }
}
