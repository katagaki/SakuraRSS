import Foundation

/// Looks up the iOS settings strings, so the Mac panes share their wording.
enum SettingsText {

    static func settings(_ key: String.LocalizationValue) -> String {
        String(localized: key, table: "Settings")
    }

    static func data(_ key: String.LocalizationValue) -> String {
        String(localized: key, table: "DataManagement")
    }
}
