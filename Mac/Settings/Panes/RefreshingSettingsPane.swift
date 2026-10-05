import Hanami
import SwiftUI

struct RefreshingSettingsPane: View {

    @AppStorage("App.FetchOnStartup") private var fetchOnStartup = true
    @AppStorage("FeedRefresh.PreloadArticleImagesMode") private var foregroundImagesMode: FetchImagesMode = .wifiOnly
    @AppStorage("BackgroundRefresh.Cooldown") private var fetchCooldown: FeedRefreshCooldown = .fiveMinutes
    @AppStorage("BackgroundRefresh.Enabled") private var periodicRefreshEnabled = true
    @AppStorage("BackgroundRefresh.Interval") private var fetchInterval = 240
    @AppStorage("BackgroundRefresh.ImageFetchMode") private var backgroundImagesMode: FetchImagesMode = .wifiOnly

    var body: some View {
        SettingsForm {
            Group {
                LabeledContent(SettingsText.settings("Section.WhenAppOpen")) {
                    Toggle(SettingsText.settings("FetchOnStartup"), isOn: $fetchOnStartup)
                }
                DownloadImagesToggle(mode: $foregroundImagesMode)
                SettingsPicker(SettingsText.settings("FetchCooldown"), selection: $fetchCooldown) {
                    ForEach(FeedRefreshCooldown.allCases, id: \.self) { cooldown in
                        Text(cooldown.settingsTitle).tag(cooldown)
                    }
                }
                LabeledContent {
                    SettingsNote(text: SettingsText.settings("RefreshCooldown.Footer"))
                } label: {
                    Text(verbatim: "")
                }
            }
            SettingsGroupSpacer()
            Group {
                LabeledContent(SettingsText.settings("Section.WhenAppClosed")) {
                    Toggle(SettingsText.settings("FetchContentPeriodically"), isOn: $periodicRefreshEnabled)
                }
                DownloadImagesToggle(mode: $backgroundImagesMode)
                    .disabled(!periodicRefreshEnabled)
                SettingsPicker(SettingsText.settings("FetchInterval"), selection: $fetchInterval) {
                    ForEach(RefreshIntervalOption.allCases, id: \.minutes) { option in
                        Text(option.title).tag(option.minutes)
                    }
                }
                .disabled(!periodicRefreshEnabled)
            }
        }
    }
}

/// A checkbox rather than iOS's menu, as Wi-Fi Only means little on a Mac.
/// Wi-Fi Only, the default, still reads as on.
private struct DownloadImagesToggle: View {

    @Binding var mode: FetchImagesMode

    var body: some View {
        LabeledContent {
            Toggle(
                SettingsText.settings("FetchImages"),
                isOn: Binding(get: { mode != .off }, set: { mode = $0 ? .always : .off })
            )
        } label: {
            Text(verbatim: "")
        }
    }
}

private enum RefreshIntervalOption: CaseIterable {
    case fifteenMinutes, thirtyMinutes, oneHour, fourHours, eightHours, twelveHours, oneDay

    var minutes: Int {
        switch self {
        case .fifteenMinutes: 15
        case .thirtyMinutes: 30
        case .oneHour: 60
        case .fourHours: 240
        case .eightHours: 480
        case .twelveHours: 720
        case .oneDay: 1440
        }
    }

    var title: String {
        switch self {
        case .fifteenMinutes: SettingsText.settings("Refresh.15min")
        case .thirtyMinutes: SettingsText.settings("Refresh.30min")
        case .oneHour: SettingsText.settings("Refresh.1hour")
        case .fourHours: SettingsText.settings("Refresh.4hours")
        case .eightHours: SettingsText.settings("Refresh.8hours")
        case .twelveHours: SettingsText.settings("Refresh.12hours")
        case .oneDay: SettingsText.settings("Refresh.24hours")
        }
    }
}

private extension FeedRefreshCooldown {
    var settingsTitle: String {
        switch self {
        case .off: SettingsText.settings("RefreshCooldown.Off")
        case .oneMinute: SettingsText.settings("RefreshCooldown.1min")
        case .fiveMinutes: SettingsText.settings("RefreshCooldown.5min")
        case .tenMinutes: SettingsText.settings("RefreshCooldown.10min")
        case .thirtyMinutes: SettingsText.settings("RefreshCooldown.30min")
        case .oneHour: SettingsText.settings("RefreshCooldown.1hour")
        }
    }
}
