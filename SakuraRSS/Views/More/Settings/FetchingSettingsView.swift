import SwiftUI

struct FetchingSettingsView: View {

    @AppStorage("App.FetchOnStartup") private var fetchOnStartup: Bool = true
    @AppStorage("FeedRefresh.PreloadArticleImagesMode")
    private var foregroundImagesMode: FetchImagesMode = .wifiOnly
    @AppStorage("BackgroundRefresh.Cooldown")
    private var fetchCooldown: FeedRefreshCooldown = .fiveMinutes
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("BackgroundRefresh.Interval") private var fetchInterval: Int = 240
    @AppStorage("BackgroundRefresh.ImageFetchMode")
    private var backgroundImagesMode: FetchImagesMode = .wifiOnly

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "FetchOnStartup", table: "Settings"), isOn: $fetchOnStartup)
                Picker(selection: $foregroundImagesMode) {
                    Text(String(localized: "FetchImages.Always", table: "Settings"))
                        .tag(FetchImagesMode.always)
                    Text(String(localized: "FetchImages.WiFiOnly", table: "Settings"))
                        .tag(FetchImagesMode.wifiOnly)
                    Text(String(localized: "FetchImages.Off", table: "Settings"))
                        .tag(FetchImagesMode.off)
                } label: {
                    Text(String(localized: "FetchImages", table: "Settings"))
                }
                Picker(selection: $fetchCooldown) {
                    Text(String(localized: "RefreshCooldown.Off", table: "Settings"))
                        .tag(FeedRefreshCooldown.off)
                    Text(String(localized: "RefreshCooldown.1min", table: "Settings"))
                        .tag(FeedRefreshCooldown.oneMinute)
                    Text(String(localized: "RefreshCooldown.5min", table: "Settings"))
                        .tag(FeedRefreshCooldown.fiveMinutes)
                    Text(String(localized: "RefreshCooldown.10min", table: "Settings"))
                        .tag(FeedRefreshCooldown.tenMinutes)
                    Text(String(localized: "RefreshCooldown.30min", table: "Settings"))
                        .tag(FeedRefreshCooldown.thirtyMinutes)
                    Text(String(localized: "RefreshCooldown.1hour", table: "Settings"))
                        .tag(FeedRefreshCooldown.oneHour)
                } label: {
                    Text(String(localized: "FetchCooldown", table: "Settings"))
                }
            } header: {
                Text(String(localized: "Section.WhenAppOpen", table: "Settings"))
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "RefreshCooldown.Footer", table: "Settings"))
                    Text(String(localized: "FetchImages.Foreground.Footer", table: "Settings"))
                }
            }

            Section {
                Toggle(String(localized: "FetchContentPeriodically", table: "Settings"),
                       isOn: $backgroundRefreshEnabled)
                if backgroundRefreshEnabled {
                    Picker(selection: $fetchInterval) {
                        Text(String(localized: "Refresh.15min", table: "Settings")).tag(15)
                        Text(String(localized: "Refresh.30min", table: "Settings")).tag(30)
                        Text(String(localized: "Refresh.1hour", table: "Settings")).tag(60)
                        Text(String(localized: "Refresh.4hours", table: "Settings")).tag(240)
                        Text(String(localized: "Refresh.8hours", table: "Settings")).tag(480)
                        Text(String(localized: "Refresh.12hours", table: "Settings")).tag(720)
                        Text(String(localized: "Refresh.24hours", table: "Settings")).tag(1440)
                    } label: {
                        Text(String(localized: "FetchInterval", table: "Settings"))
                    }
                }
                Picker(selection: $backgroundImagesMode) {
                    Text(String(localized: "FetchImages.Always", table: "Settings"))
                        .tag(FetchImagesMode.always)
                    Text(String(localized: "FetchImages.WiFiOnly", table: "Settings"))
                        .tag(FetchImagesMode.wifiOnly)
                    Text(String(localized: "FetchImages.Off", table: "Settings"))
                        .tag(FetchImagesMode.off)
                } label: {
                    Text(String(localized: "FetchImages", table: "Settings"))
                }
            } header: {
                Text(String(localized: "Section.WhenAppClosed", table: "Settings"))
            } footer: {
                Text(String(localized: "FetchImages.Background.Footer", table: "Settings"))
            }
        }
        .animation(.smooth.speed(2.0), value: backgroundRefreshEnabled)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Refreshing", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}
