import SwiftUI

/// Letterwood's look, taken from the team's web prototype: bright sky, mint hills, sunny fireflies,
/// and chunky "sticker" shapes with thick ink outlines and hard shadows.
enum Theme {
    static let ink = Color(hex: 0x241F54)
    static let inkSoft = Color(hex: 0x4B4680)
    static let muted = Color(hex: 0x5A5592)
    static let background = Color(hex: 0xECEEFF)
    static let panel = Color.white
    static let soft = Color(hex: 0xE1E4FF)
    static let mint = Color(hex: 0x2FB985)
    static let mintDark = Color(hex: 0x1C8A63)
    static let sun = Color(hex: 0xFFC43D)
    static let berry = Color(hex: 0xEE4F8B)
    static let blush = Color(hex: 0xFFD3E3)
    static let earth = Color(hex: 0x7B5BC9)
    static let water = Color(hex: 0x52C2FF)
    static let sky1 = Color(hex: 0xBFE6FF)
    static let sky2 = Color(hex: 0xEAF7FF)
    static let hill1 = Color(hex: 0x8EDDBB)
    static let hill2 = Color(hex: 0x58C79D)
    static let warnBackground = Color(hex: 0xFFF1C9)
    static let warnInk = Color(hex: 0x4A3600)
    static let line: CGFloat = 3

    enum FontRole {
        /// Chunky rounded headings, like the prototype's Bagel Fat One.
        case display
        /// Friendly body text.
        case body
        /// Words a child reads. Plain shapes and wide letter spacing, like the prototype's Lexend.
        case reading
    }

    static func font(_ role: FontRole, _ size: CGFloat) -> Font {
        switch role {
        case .display: .system(size: size, weight: .black, design: .rounded)
        case .body: .system(size: size, weight: .medium, design: .rounded)
        case .reading: .system(size: size, weight: .semibold, design: .default)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Uses the comfort setting for larger text, so every screen grows together.
private struct ThemedFont: ViewModifier {
    @Environment(Comfort.self) private var comfort
    let role: Theme.FontRole
    let size: CGFloat

    func body(content: Content) -> some View {
        content.font(Theme.font(role, size * (comfort.largerText ? 1.18 : 1)))
    }
}

/// A rounded panel with a thick ink outline and a hard shadow underneath.
private struct Chunky: ViewModifier {
    var fill: Color
    var radius: CGFloat
    var drop: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(fill).overlay(shape.strokeBorder(Theme.ink, lineWidth: Theme.line)))
            .background(shape.fill(Theme.ink).offset(y: drop))
            .padding(.bottom, drop)
    }
}

extension View {
    func themed(_ role: Theme.FontRole, _ size: CGFloat) -> some View {
        modifier(ThemedFont(role: role, size: size))
    }

    func chunky(_ fill: Color = Theme.panel, radius: CGFloat = 24, drop: CGFloat = 5) -> some View {
        modifier(Chunky(fill: fill, radius: radius, drop: drop))
    }
}

/// The chunky button from the prototype. It sinks into its shadow when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Theme.mint
    var radius: CGFloat = 18
    var drop: CGFloat = 5
    var size: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonBody(configuration: configuration, fill: fill, radius: radius, drop: drop, size: size)
    }

    private struct ChunkyButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let fill: Color
        let radius: CGFloat
        let drop: CGFloat
        let size: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            let pressed = configuration.isPressed
            configuration.label
                .themed(.display, size)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .frame(minHeight: 56)
                .background(shape.fill(fill).overlay(shape.strokeBorder(Theme.ink, lineWidth: Theme.line)))
                .offset(y: pressed ? drop - 1 : 0)
                .background(shape.fill(Theme.ink).offset(y: drop))
                .padding(.bottom, drop)
                .opacity(isEnabled ? 1 : 0.45)
                .animation(.easeOut(duration: 0.08), value: pressed)
        }
    }
}

/// Small text tag in a rounded outline, for notes like "4 islands".
struct Pill: View {
    let text: String

    var body: some View {
        Text(text)
            .themed(.body, 15)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.panel).overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2)))
    }
}

/// Small uppercase label above a heading.
struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(Theme.muted)
    }
}

/// The light screen background used everywhere.
struct ScreenBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}
