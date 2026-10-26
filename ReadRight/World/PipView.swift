import SwiftUI

/// Pip: a round berry-colored sprout with two leaves, drawn from the prototype's design.
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

    /// Coordinates are on an 80 × 80 grid, the same as the prototype's SVG.
    static func draw(in context: inout GraphicsContext, mood: Mood, body bodyColor: Color = Theme.berry) {
        let ink = Theme.ink
        context.fill(Path(ellipseIn: CGRect(x: 18, y: 71.5, width: 44, height: 7)), with: .color(.black.opacity(0.18)))

        var leftLeaf = Path()
        leftLeaf.move(to: CGPoint(x: 40, y: 15))
        leftLeaf.addCurve(to: CGPoint(x: 21, y: 7), control1: CGPoint(x: 37, y: 2), control2: CGPoint(x: 25, y: 3))
        leftLeaf.addCurve(to: CGPoint(x: 40, y: 15), control1: CGPoint(x: 27, y: 10), control2: CGPoint(x: 33, y: 12))
        var rightLeaf = Path()
        rightLeaf.move(to: CGPoint(x: 40, y: 15))
        rightLeaf.addCurve(to: CGPoint(x: 57, y: 7), control1: CGPoint(x: 42, y: 6), control2: CGPoint(x: 52, y: 4))
        rightLeaf.addCurve(to: CGPoint(x: 40, y: 15), control1: CGPoint(x: 52, y: 11), control2: CGPoint(x: 46, y: 13))
        for leaf in [leftLeaf, rightLeaf] {
            context.fill(leaf, with: .color(Theme.mint))
            context.stroke(leaf, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }

        let bodyCircle = Path(ellipseIn: CGRect(x: 12, y: 17, width: 56, height: 56))
        context.fill(bodyCircle, with: .color(bodyColor))
        context.stroke(bodyCircle, with: .color(ink), lineWidth: 3)
        context.fill(Path(ellipseIn: CGRect(x: 25, y: 45, width: 30, height: 24)), with: .color(Theme.blush))

        // Eyes look up a little while Pip is listening.
        let look: CGFloat = mood == .listening ? -1.5 : 0
        for x in [30.0, 50.0] {
            let eye = Path(ellipseIn: CGRect(x: x - 7.5, y: 33.5, width: 15, height: 15))
            context.fill(eye, with: .color(.white))
            context.stroke(eye, with: .color(ink), lineWidth: 2.5)
            context.fill(Path(ellipseIn: CGRect(x: x + 2 - 3.4, y: 42 + look - 3.4, width: 6.8, height: 6.8)), with: .color(ink))
            context.fill(Path(ellipseIn: CGRect(x: x + 3 - 1.1, y: 40.8 + look - 1.1, width: 2.2, height: 2.2)), with: .color(.white))
        }

        var mouth = Path()
        switch mood {
        case .calm:
            mouth.move(to: CGPoint(x: 34, y: 53))
            mouth.addQuadCurve(to: CGPoint(x: 46, y: 53), control: CGPoint(x: 40, y: 59))
            context.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
        case .happy:
            mouth.move(to: CGPoint(x: 32, y: 52))
            mouth.addQuadCurve(to: CGPoint(x: 48, y: 52), control: CGPoint(x: 40, y: 63))
            mouth.closeSubpath()
            context.fill(mouth, with: .color(ink))
        case .listening:
            context.fill(Path(ellipseIn: CGRect(x: 37, y: 52, width: 6, height: 6)), with: .color(ink))
        }

        context.fill(Path(ellipseIn: CGRect(x: 21, y: 68, width: 16, height: 8)), with: .color(ink))
        context.fill(Path(ellipseIn: CGRect(x: 43, y: 68, width: 16, height: 8)), with: .color(ink))
    }
}

/// A gentle up-and-down float. Turned off by "Calm motion".
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

/// One of Pip's friends, used for made-up words in Word Woods. Same shape as Pip in other colors.
struct CreatureView: View {
    let index: Int
    var size: CGFloat = 70

    private static let colors: [Color] = [Theme.water, Theme.sun, Theme.earth, Theme.mint]

    var body: some View {
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 80, y: canvasSize.height / 80)
            PipView.draw(in: &context, mood: .happy, body: Self.colors[index % Self.colors.count])
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
