import SwiftUI
import Hanami

extension Color {

    /// On Mac Catalyst, resolves to the user's macOS system accent color
    /// (`UIColor.tintColor`). Elsewhere, falls back to the asset catalog's
    /// `AccentColor`.
    static var platformAccent: Color {
        #if targetEnvironment(macCatalyst)
        Color(uiColor: .tintColor)
        #else
        Color.accentColor
        #endif
    }

    static let lime = Color(
        light: ColorComponents(red: 0.50, green: 0.78, blue: 0.10),
        dark: ColorComponents(red: 0.65, green: 0.90, blue: 0.30)
    )

    static let magenta = Color(
        light: ColorComponents(red: 0.85, green: 0.15, blue: 0.55),
        dark: ColorComponents(red: 0.95, green: 0.35, blue: 0.70)
    )

    static let slate = Color(
        light: ColorComponents(red: 0.40, green: 0.48, blue: 0.55),
        dark: ColorComponents(red: 0.60, green: 0.68, blue: 0.75)
    )

    static let beige = Color(
        light: ColorComponents(red: 0.78, green: 0.68, blue: 0.50),
        dark: ColorComponents(red: 0.88, green: 0.78, blue: 0.62)
    )
}

struct ColorComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    var platformColor: PlatformColor {
        PlatformColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

private extension Color {

    init(light: ColorComponents, dark: ColorComponents) {
        #if canImport(UIKit)
        self.init(uiColor: PlatformColor { traits in
            traits.userInterfaceStyle == .dark ? dark.platformColor : light.platformColor
        })
        #else
        self.init(nsColor: PlatformColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? dark.platformColor
                : light.platformColor
        })
        #endif
    }
}
