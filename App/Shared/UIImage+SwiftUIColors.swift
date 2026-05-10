import SwiftUI
import UIKit
import Hanami

extension UIImage {

    var averageColor: Color {
        guard let rgb = ensureIconDerivedMetrics().averageColor, rgb.count >= 3 else {
            return .gray
        }
        return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
    }

    var prominentColors: [Color] {
        let metrics = ensureIconDerivedMetrics()
        guard let stored = metrics.prominentColors, !stored.isEmpty else {
            return [averageColor]
        }
        return stored.compactMap { rgb -> Color? in
            guard rgb.count >= 3 else { return nil }
            return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
    }

    func cardBackgroundColor(isDarkMode: Bool) -> Color {
        guard let avg = averageColorComponents else {
            return isDarkMode ? Color(white: 0.15) : Color(white: 0.9)
        }

        if isDarkMode {
            let blend: CGFloat = 0.35
            return Color(
                red: blend * avg.red,
                green: blend * avg.green,
                blue: blend * avg.blue
            )
        } else {
            let whiteBlend: CGFloat = 0.65
            return Color(
                red: whiteBlend + (1 - whiteBlend) * avg.red,
                green: whiteBlend + (1 - whiteBlend) * avg.green,
                blue: whiteBlend + (1 - whiteBlend) * avg.blue
            )
        }
    }

    var nearWhiteAverageGradient: LinearGradient {
        guard let rgb = ensureIconDerivedMetrics().averageColor, rgb.count >= 3 else {
            return LinearGradient(
                colors: [Color(.secondarySystemBackground)],
                startPoint: .bottom,
                endPoint: .top
            )
        }

        let mean = (rgb[0] + rgb[1] + rgb[2]) / 3.0
        let saturationBoost: Double = 1.5
        let boostedR = max(0, min(1, mean + (rgb[0] - mean) * saturationBoost))
        let boostedG = max(0, min(1, mean + (rgb[1] - mean) * saturationBoost))
        let boostedB = max(0, min(1, mean + (rgb[2] - mean) * saturationBoost))

        let topBlend: Double = 0.7
        let bottomBlend: Double = 0.55
        let top = Color(
            red: topBlend + (1 - topBlend) * boostedR,
            green: topBlend + (1 - topBlend) * boostedG,
            blue: topBlend + (1 - topBlend) * boostedB
        )
        let bottom = Color(
            red: bottomBlend + (1 - bottomBlend) * boostedR,
            green: bottomBlend + (1 - bottomBlend) * boostedG,
            blue: bottomBlend + (1 - bottomBlend) * boostedB
        )
        return LinearGradient(colors: [bottom, top], startPoint: .bottom, endPoint: .top)
    }
}
