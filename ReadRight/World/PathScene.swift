import SwiftUI

/// The side-scrolling walk from the prototype: Pip stands on a stepping stone and hops
/// to the next one after every try. Fireflies wait above the stones ahead, and a lamp marks the end.
struct PathScene: View {
    /// The stone Pip stands on, from 0 to `total`.
    let step: Int
    let total: Int
    var listening = false

    @Environment(Comfort.self) private var comfort

    private let spacing: CGFloat = 110
    private let stoneWidth: CGFloat = 82
    private static let heights: [CGFloat] = [34, 52, 40, 62, 44, 56, 36, 64]

    private func height(_ index: Int) -> CGFloat {
        Self.heights[index % Self.heights.count]
    }

    var body: some View {
        GeometryReader { geometry in
            let anchor = geometry.size.width * 0.3
            let shift = anchor - stoneWidth / 2 - CGFloat(step) * spacing
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [Theme.sky1, Theme.sky2], startPoint: .top, endPoint: .bottom)
                Clouds()
                    .offset(x: -CGFloat(step) * 16)
                Hills()
                    .frame(width: 1900, height: 100)
                    .offset(x: -CGFloat(step) * 38)

                ZStack(alignment: .bottomLeading) {
                    ForEach(0...total, id: \.self) { index in
                        Stone()
                            .frame(width: stoneWidth, height: height(index))
                            .offset(x: CGFloat(index) * spacing)
                        if index > step, index < total {
                            Firefly()
                                .offset(x: CGFloat(index) * spacing + stoneWidth / 2 - 8, y: -(height(index) + 46))
                        }
                    }
                    Lamp()
                        .offset(x: CGFloat(total) * spacing + stoneWidth / 2 - 16, y: 0)
                }
                .offset(x: shift)

                PipView(mood: listening ? .listening : .calm, size: 58, bob: false)
                    .modifier(Hop(trigger: step, active: !comfort.calmMotion))
                    .offset(x: anchor - 29, y: -(height(step) - 3))

                FireflyCount(count: step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(10)
            }
            .animation(comfort.calmMotion ? nil : .spring(response: 0.7, dampingFraction: 0.86), value: step)
        }
        .frame(height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.ink, lineWidth: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pip is on stone \(step + 1). \(step) fireflies lit.")
    }
}

/// Pip's hop: up, stretch, land, squash. Plays every time `trigger` changes.
private struct Hop: ViewModifier {
    let trigger: Int
    let active: Bool

    struct Values {
        var lift: CGFloat = 0
        var stretch: CGFloat = 1
    }

    func body(content: Content) -> some View {
        if active {
            content.keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view
                    .scaleEffect(x: 2 - value.stretch, y: value.stretch, anchor: .bottom)
                    .offset(y: value.lift)
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    CubicKeyframe(-62, duration: 0.33)
                    CubicKeyframe(0, duration: 0.3)
                    CubicKeyframe(0, duration: 0.12)
                }
                KeyframeTrack(\.stretch) {
                    CubicKeyframe(1.08, duration: 0.33)
                    CubicKeyframe(1, duration: 0.25)
                    CubicKeyframe(0.9, duration: 0.07)
                    CubicKeyframe(1, duration: 0.1)
                }
            }
        } else {
            content
        }
    }
}

private struct Stone: View {
    var body: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                .fill(Theme.earth)
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14).strokeBorder(Theme.ink, lineWidth: 3))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.mint)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.ink, lineWidth: 3))
                .frame(height: 16)
                .padding(.horizontal, -2)
            HStack(spacing: 30) {
                Circle().fill(.white.opacity(0.28)).frame(width: 9, height: 9)
                Circle().fill(.white.opacity(0.22)).frame(width: 9, height: 9).offset(y: 12)
            }
            .padding(.top, 26)
        }
    }
}

private struct Firefly: View {
    @Environment(Comfort.self) private var comfort

    var body: some View {
        Circle()
            .fill(Theme.sun)
            .frame(width: 16, height: 16)
            .shadow(color: Theme.sun.opacity(0.9), radius: 8)
            .modifier(Bobbing(active: !comfort.calmMotion))
    }
}

private struct Lamp: View {
    var body: some View {
        VStack(spacing: -4) {
            Circle()
                .fill(Theme.sun)
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 3))
                .frame(width: 32, height: 32)
                .shadow(color: Theme.sun.opacity(0.8), radius: 14)
            Capsule().fill(Theme.ink).frame(width: 7, height: 92)
        }
    }
}

private struct Clouds: View {
    private let clouds: [(x: CGFloat, y: CGFloat, width: CGFloat)] = [
        (30, 22, 84), (250, 52, 120), (510, 28, 92), (760, 60, 128), (1010, 24, 90), (1260, 50, 120),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(clouds.indices, id: \.self) { index in
                let cloud = clouds[index]
                ZStack(alignment: .topLeading) {
                    Capsule().fill(.white.opacity(0.9)).frame(width: cloud.width, height: 24)
                    Capsule().fill(.white.opacity(0.9)).frame(width: cloud.width * 0.44, height: 24)
                        .offset(x: cloud.width * 0.22, y: -12)
                }
                .offset(x: cloud.x, y: cloud.y)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct Hills: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            WaveShape(peaks: 9, base: 0.55).fill(Theme.hill1)
            WaveShape(peaks: 7, base: 0.78).fill(Theme.hill2)
        }
    }
}

/// Rolling hills along the bottom edge.
private struct WaveShape: Shape {
    let peaks: Int
    /// How far down the hills start, as a fraction of the height.
    let base: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            let segment = rect.width / CGFloat(peaks)
            let top = rect.height * (1 - base)
            path.move(to: CGPoint(x: 0, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: top + 20))
            for index in 0..<peaks {
                let startX = CGFloat(index) * segment
                path.addQuadCurve(
                    to: CGPoint(x: startX + segment, y: top + (index.isMultiple(of: 2) ? 10 : 22)),
                    control: CGPoint(x: startX + segment / 2, y: top - 26)
                )
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct FireflyCount: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.sun).frame(width: 12, height: 12).shadow(color: Theme.sun, radius: 4)
            Text("\(count) fireflies")
                .themed(.body, 15)
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.panel).overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.line)))
    }
}
