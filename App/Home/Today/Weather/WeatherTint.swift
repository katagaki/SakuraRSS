import SwiftUI

enum WeatherTint {
    static func color(for symbolName: String) -> Color {
        let name = symbolName.lowercased()
        if name.contains("bolt") {
            return .purple
        }
        if name.contains("snow") || name.contains("sleet")
            || name.contains("hail") || name.contains("flurr") {
            return .cyan
        }
        if name.contains("rain") || name.contains("drizzle") { return .blue }
        if name.contains("fog") || name.contains("haze")
            || name.contains("smoke") || name.contains("dust") {
            return .gray
        }
        if name.contains("wind") || name.contains("tornado") || name.contains("hurricane") {
            return .teal
        }
        if name.contains("cloud") {
            if name.contains("sun") {
                return .blue
            }
            if name.contains("moon") {
                return .indigo
            }
            return .gray
        }
        if name.contains("moon") || name.contains("star") {
            return .indigo
        }
        return .blue
    }
}
