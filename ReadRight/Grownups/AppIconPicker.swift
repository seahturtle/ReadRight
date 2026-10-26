import SwiftUI
import UIKit

/// Switch between the app icons: Classic Pip and Retro Pip (pixel art).
/// iOS shows a short "You have changed the icon" message after a switch.
struct AppIconPicker: View {
    private struct Choice: Identifiable {
        /// nil is the main icon.
        let iconName: String?
        let title: String
        let preview: String
        var id: String { title }
    }

    private let choices = [
        Choice(iconName: nil, title: "Classic Pip", preview: "IconPreviewClassic"),
        Choice(iconName: "AppIcon-Retro", title: "Retro Pip", preview: "IconPreviewRetro"),
    ]

    @State private var current = UIApplication.shared.alternateIconName
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                ForEach(choices) { choice in
                    Button {
                        Task { await select(choice.iconName) }
                    } label: {
                        VStack(spacing: 6) {
                            Image(choice.preview)
                                .resizable()
                                .interpolation(choice.iconName == nil ? .high : .none)
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .strokeBorder(current == choice.iconName ? Theme.mintDark : Theme.ink.opacity(0.2), lineWidth: current == choice.iconName ? 4 : 1.5)
                                )
                            Text(choice.title).themed(.body, 14).foregroundStyle(Theme.ink)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(current == choice.iconName ? .isSelected : [])
                }
            }
            if let errorText {
                Text(errorText).themed(.body, 13).foregroundStyle(Theme.warnInk)
            }
        }
    }

    private func select(_ name: String?) async {
        guard UIApplication.shared.supportsAlternateIcons, name != current else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(name)
            current = UIApplication.shared.alternateIconName
            errorText = nil
        } catch {
            errorText = "The icon couldn't be changed: \(error.localizedDescription)"
        }
    }
}
