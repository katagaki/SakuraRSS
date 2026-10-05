import SwiftUI

enum TodayGreeting {

    static func text(at date: Date) -> AttributedString {
        let key: String = switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "TodayGreeting.Morning"
        case 12..<18: "TodayGreeting.Afternoon"
        case 18..<21: "TodayGreeting.EarlyEvening"
        case 21..<24: "TodayGreeting.Evening"
        default: "TodayGreeting.LateNight"
        }
        var greeting = AttributedString(String(localized: String.LocalizationValue(key), table: "Home"))
        var period = AttributedString(String(localized: "TodayGreeting.Period", table: "Home"))
        period.foregroundColor = .accentColor
        greeting.append(period)
        return greeting
    }
}
