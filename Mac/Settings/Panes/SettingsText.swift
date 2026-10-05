import Foundation

/// Looks up the iOS settings strings, so the Mac panes share their wording.
enum SettingsText {

    static func settings(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: "Settings")
    }

    static func data(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: "DataManagement")
    }
}
