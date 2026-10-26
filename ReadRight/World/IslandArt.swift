import SwiftUI

/// The island pictures from the prototype's map, drawn on a 200 × 124 grid.
struct IslandArt: View {
    let activity: Activity

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 200, y: size.height / 124)
            Self.drawBase(in: &context)
            switch activity {
            case .soundSprings: Self.drawSpring(in: &context)
            case .echoCave: Self.drawCave(in: &context)
            case .wordWoods: Self.drawWoods(in: &context)
            case .fireflyDash: Self.drawFireflies(in: &context)
            }
        }
        .aspectRatio(200 / 124, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private static let ink = Theme.ink

    private static func outlined(_ path: Path, _ fill: Color, _ width: CGFloat, in context: inout GraphicsContext) {
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: width, lineJoin: .round))
    }

    private static func drawBase(in context: inout GraphicsContext) {
        outlined(Path(ellipseIn: CGRect(x: 16, y: 38, width: 168, height: 52)), Theme.mint, 4, in: &context)
        var earth = Path()
        earth.move(to: CGPoint(x: 20, y: 70))
        earth.addCurve(to: CGPoint(x: 100, y: 122), control1: CGPoint(x: 28, y: 106), control2: CGPoint(x: 56, y: 122))
        earth.addCurve(to: CGPoint(x: 180, y: 70), control1: CGPoint(x: 144, y: 122), control2: CGPoint(x: 172, y: 106))
        earth.addCurve(to: CGPoint(x: 100, y: 92), control1: CGPoint(x: 160, y: 86), control2: CGPoint(x: 128, y: 92))
        earth.addCurve(to: CGPoint(x: 20, y: 70), control1: CGPoint(x: 72, y: 92), control2: CGPoint(x: 40, y: 86))
        earth.closeSubpath()
        outlined(earth, Theme.earth, 4, in: &context)
    }

    private static func drawSpring(in context: inout GraphicsContext) {
        outlined(Path(ellipseIn: CGRect(x: 54, y: 46, width: 92, height: 28)), Theme.water, 3.5, in: &context)
        context.stroke(Path(ellipseIn: CGRect(x: 72, y: 52, width: 56, height: 16)), with: .color(ink.opacity(0.6)), lineWidth: 2.5)
        var drop = Path()
        drop.move(to: CGPoint(x: 100, y: 14))
        drop.addCurve(to: CGPoint(x: 100, y: 42), control1: CGPoint(x: 110, y: 28), control2: CGPoint(x: 114, y: 36))
        drop.addCurve(to: CGPoint(x: 100, y: 14), control1: CGPoint(x: 86, y: 36), control2: CGPoint(x: 90, y: 28))
        drop.closeSubpath()
        outlined(drop, Theme.water, 3.5, in: &context)
    }

    private static func drawCave(in context: inout GraphicsContext) {
        var rock = Path()
        rock.move(to: CGPoint(x: 44, y: 66))
        rock.addQuadCurve(to: CGPoint(x: 156, y: 66), control: CGPoint(x: 100, y: -14))
        rock.closeSubpath()
        outlined(rock, Color(hex: 0xB7B0E6), 3.5, in: &context)
        var mouth = Path()
        mouth.move(to: CGPoint(x: 80, y: 66))
        mouth.addQuadCurve(to: CGPoint(x: 120, y: 66), control: CGPoint(x: 100, y: 18))
        mouth.closeSubpath()
        context.fill(mouth, with: .color(ink))
        // Echo rings coming out of the cave.
        for (index, radius) in [10.0, 18.0].enumerated() {
            var arc = Path()
            arc.addArc(center: CGPoint(x: 128, y: 40), radius: radius, startAngle: .degrees(-50), endAngle: .degrees(50), clockwise: false)
            context.stroke(arc, with: .color(ink.opacity(index == 0 ? 0.9 : 0.6)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    private static func drawWoods(in context: inout GraphicsContext) {
        context.fill(Path(CGRect(x: 52, y: 44, width: 8, height: 22)), with: .color(ink))
        outlined(triangle(CGPoint(x: 56, y: 12), CGPoint(x: 34, y: 48), CGPoint(x: 78, y: 48)), Theme.mintDark, 3.5, in: &context)
        context.fill(Path(CGRect(x: 132, y: 40, width: 8, height: 26)), with: .color(ink))
        outlined(triangle(CGPoint(x: 136, y: 6), CGPoint(x: 110, y: 44), CGPoint(x: 162, y: 44)), Theme.mintDark, 3.5, in: &context)
        outlined(Path(roundedRect: CGRect(x: 92, y: 48, width: 30, height: 20), cornerRadius: 3), Theme.sun, 3, in: &context)
        var spine = Path()
        spine.move(to: CGPoint(x: 107, y: 48))
        spine.addLine(to: CGPoint(x: 107, y: 68))
        context.stroke(spine, with: .color(ink), lineWidth: 2.5)
    }

    private static func drawFireflies(in context: inout GraphicsContext) {
        outlined(triangle(CGPoint(x: 84, y: 18), CGPoint(x: 40, y: 64), CGPoint(x: 124, y: 64)), Theme.hill2, 3.5, in: &context)
        outlined(triangle(CGPoint(x: 132, y: 32), CGPoint(x: 96, y: 64), CGPoint(x: 168, y: 64)), Theme.hill1, 3.5, in: &context)
        let dots: [(CGPoint, FireflyColor)] = [
            (CGPoint(x: 60, y: 22), .red), (CGPoint(x: 110, y: 12), .blue), (CGPoint(x: 150, y: 20), .yellow), (CGPoint(x: 172, y: 40), .green),
        ]
        for (point, color) in dots {
            let rect = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
            context.fill(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(color.swatch.opacity(0.25)))
            outlined(Path(ellipseIn: rect), color.swatch, 2, in: &context)
        }
    }

    private static func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
        Path { path in
            path.move(to: a)
            path.addLine(to: b)
            path.addLine(to: c)
            path.closeSubpath()
        }
    }
}
