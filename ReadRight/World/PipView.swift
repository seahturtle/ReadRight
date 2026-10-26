import SwiftUI

/// Pip, a small round firefly. Letterwood is full of fireflies, and every try lights one,
/// so Pip is one too.
///
/// Drawn to look gentle to young children: small dot eyes set low and wide apart, rosy cheeks,
/// a tiny smile, and only round shapes. No big white eyes or open mouths, which can look startling.
/// Every screen uses `PipView`, so changing it here changes Pip everywhere.
struct PipView: View {
    enum Mood {
        case calm, happy, listening
    }

    var mood: Mood = .calm
    var size: CGFloat = 80
    var bob = true

    @Environment(Comfort.self) private var comfort

    var body: some View {
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 80, y: canvasSize.height / 80)
            Self.draw(in: &context, mood: mood)
        }
        .frame(width: size, height: size)
        .modifier(Bobbing(active: bob && !comfort.calmMotion))
        .accessibilityHidden(true)
    }

    /// Coordinates are on an 80 × 80 grid.
    static func draw(in context: inout GraphicsContext, mood: Mood, body bodyColor: Color = Theme.sun, glows: Bool = true) {
        let ink = Theme.ink

        // Soft shadow on the ground, and a warm glow around Pip.
        context.fill(Path(ellipseIn: CGRect(x: 25, y: 73, width: 30, height: 4)), with: .color(.black.opacity(0.12)))
        if glows {
            context.fill(Path(ellipseIn: CGRect(x: 4, y: 10, width: 72, height: 64)), with: .color(Theme.sun.opacity(0.22)))
        }

        // Two see-through wings sticking out to the sides, so they read as wings, not ears.
        for (x, angle) in [(14.0, -18.0), (66.0, 18.0)] {
            var wing = context
            wing.translateBy(x: x, y: 36)
            wing.rotate(by: .degrees(angle))
            let rect = CGRect(x: -12, y: -7, width: 24, height: 14)
            wing.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xE8F6FF).opacity(0.95)))
            wing.stroke(Path(ellipseIn: rect), with: .color(ink.opacity(0.45)), lineWidth: 1.8)
        }

        // Antennae with round tips.
        for (start, control, tip) in [
            (CGPoint(x: 34, y: 24), CGPoint(x: 29, y: 17), CGPoint(x: 28, y: 9)),
            (CGPoint(x: 46, y: 24), CGPoint(x: 51, y: 17), CGPoint(x: 52, y: 9)),
        ] {
            var antenna = Path()
            antenna.move(to: start)
            antenna.addQuadCurve(to: tip, control: control)
            context.stroke(antenna, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: tip.x - 3, y: tip.y - 3, width: 6, height: 6)), with: .color(Theme.berry))
        }

        // A round body with a glowing tummy.
        let bodyRect = CGRect(x: 16, y: 21, width: 48, height: 48)
        let bodyPath = Path(ellipseIn: bodyRect)
        context.fill(bodyPath, with: .color(bodyColor))
        var tummy = context
        tummy.clip(to: bodyPath)
        tummy.fill(Path(ellipseIn: CGRect(x: 20, y: 52, width: 40, height: 22)), with: .color(Color(hex: 0xFFF6D5)))
        context.stroke(bodyPath, with: .color(ink), lineWidth: 2.5)

        // Rosy cheeks.
        context.fill(Path(ellipseIn: CGRect(x: 22.5, y: 46, width: 8, height: 5)), with: .color(Theme.berry.opacity(0.35)))
        context.fill(Path(ellipseIn: CGRect(x: 49.5, y: 46, width: 8, height: 5)), with: .color(Theme.berry.opacity(0.35)))

        // Small dot eyes, low and wide apart. Happy eyes are gentle closed arcs.
        for x in [31.0, 49.0] {
            if mood == .happy {
                var arc = Path()
                arc.move(to: CGPoint(x: x - 3.5, y: 43))
                arc.addQuadCurve(to: CGPoint(x: x + 3.5, y: 43), control: CGPoint(x: x, y: 38.5))
                context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            } else {
                context.fill(Path(ellipseIn: CGRect(x: x - 2.6, y: 38.5, width: 5.2, height: 6.4)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: x - 0.6, y: 39.4, width: 2, height: 2)), with: .color(.white))
            }
        }

        // A tiny mouth.
        switch mood {
        case .calm:
            var smile = Path()
            smile.move(to: CGPoint(x: 37, y: 48))
            smile.addQuadCurve(to: CGPoint(x: 43, y: 48), control: CGPoint(x: 40, y: 51))
            context.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        case .happy:
            var smile = Path()
            smile.move(to: CGPoint(x: 36, y: 47.5))
            smile.addQuadCurve(to: CGPoint(x: 44, y: 47.5), control: CGPoint(x: 40, y: 53.5))
            smile.closeSubpath()
            context.fill(smile, with: .color(ink))
        case .listening:
            context.fill(Path(ellipseIn: CGRect(x: 38.4, y: 47, width: 3.2, height: 3.6)), with: .color(ink))
        }
    }
}

/// A gentle up-and-down hover. Turned off by "Calm motion".
struct Bobbing: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([0.0, -4.0]) { view, offset in
                view.offset(y: offset)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        } else {
            content
        }
    }
}

/// One of Pip's firefly friends, used for made-up words in Word Woods.
struct CreatureView: View {
    let index: Int
    var size: CGFloat = 70

    private static let colors: [Color] = [Color(hex: 0x9BD9FF), Color(hex: 0xB9F0D4), Color(hex: 0xFFC2D9), Color(hex: 0xD8CCFF)]

    var body: some View {
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 80, y: canvasSize.height / 80)
            PipView.draw(in: &context, mood: .happy, body: Self.colors[index % Self.colors.count], glows: false)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
