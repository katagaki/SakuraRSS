import SwiftUI

/// Localized greeting + sentence terminator for the Today section header.
struct TodayGreeting {
    let text: String
    let terminator: String

    static func from(date: Date) -> TodayGreeting {
        let hour = Calendar.current.component(.hour, from: date)
        let key: String
        switch hour {
        case 5..<12: key = "TodayGreeting.Morning"
        case 12..<18: key = "TodayGreeting.Afternoon"
        case 18..<21: key = "TodayGreeting.EarlyEvening"
        case 21..<24: key = "TodayGreeting.Evening"
        default: key = "TodayGreeting.LateNight"
        }
        let body = String(localized: String.LocalizationValue(key), table: "Home")
        let terminator = String(localized: "TodayGreeting.Period", table: "Home")
        return TodayGreeting(text: body, terminator: terminator)
    }

    /// Top→bottom gradient evoking the sky at the current hour. Five anchor
    /// points (one per greeting bucket centroid) are linearly interpolated and
    /// wrapped around midnight so the color shifts continuously rather than
    /// snapping when a bucket boundary is crossed.
    static func periodGradient(at date: Date) -> LinearGradient {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hours = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
        let stops = interpolatedStops(hours: hours)
        return LinearGradient(
            colors: [stops.top, stops.bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private struct GradientStops {
        var top: SIMD3<Double>
        var bottom: SIMD3<Double>
    }

    /// Centered on each greeting bucket so the color is most "morning-like" at
    /// the middle of the morning band, etc.; the 24h wrap means late night
    /// lerps smoothly into morning across the 2.5h → 8.5h gap.
    private static let anchors: [(h: Double, stops: GradientStops)] = [
        // 0–4:59 night, anchor 02:30 : deep purple → deep blue
        (2.5, GradientStops(
            top: SIMD3(0.28, 0.14, 0.50),
            bottom: SIMD3(0.08, 0.14, 0.40)
        )),
        // 5–11:59 morning, anchor 08:30 : dusty purple → warm gold (white-text safe)
        (8.5, GradientStops(
            top: SIMD3(0.55, 0.40, 0.78),
            bottom: SIMD3(0.95, 0.60, 0.25)
        )),
        // 12–17:59 afternoon, anchor 14:30 : blue → lighter blue
        (14.5, GradientStops(
            top: SIMD3(0.25, 0.55, 0.95),
            bottom: SIMD3(0.62, 0.85, 1.00)
        )),
        // 18–20:59 early evening, anchor 19:30 : blue → orange (dusk)
        (19.5, GradientStops(
            top: SIMD3(0.30, 0.50, 0.85),
            bottom: SIMD3(1.00, 0.55, 0.20)
        )),
        // 21–23:59 evening, anchor 22:00 : deep purple → orange (last light)
        (22.0, GradientStops(
            top: SIMD3(0.32, 0.18, 0.55),
            bottom: SIMD3(1.00, 0.48, 0.20)
        ))
    ]

    private static func interpolatedStops(hours: Double) -> (top: Color, bottom: Color) {
        var startIdx = anchors.count - 1
        var endIdx = 0
        for index in 0..<anchors.count where hours < anchors[index].h {
            endIdx = index
            startIdx = index == 0 ? anchors.count - 1 : index - 1
            break
        }

        let startH = anchors[startIdx].h
        let endH = anchors[endIdx].h
        var span = endH - startH
        if span <= 0 { span += 24 }
        var progress = hours - startH
        if progress < 0 { progress += 24 }
        let progressClamped = max(0, min(1, progress / span))

        let top = lerp(anchors[startIdx].stops.top, anchors[endIdx].stops.top, progressClamped)
        let bottom = lerp(anchors[startIdx].stops.bottom, anchors[endIdx].stops.bottom, progressClamped)
        return (color(top), color(bottom))
    }

    private static func lerp(
        _ start: SIMD3<Double>,
        _ end: SIMD3<Double>,
        _ progress: Double
    ) -> SIMD3<Double> {
        start + (end - start) * progress
    }

    private static func color(_ stop: SIMD3<Double>) -> Color {
        Color(red: stop.x, green: stop.y, blue: stop.z)
    }
}
