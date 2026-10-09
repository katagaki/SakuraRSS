import SwiftUI

struct TodayWeatherSettingsSheet: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage(TodayWeatherService.enabledKey) private var isWeatherEnabled: Bool = true
    @AppStorage("Today.Weather.GraphMode") private var graphMode: WeatherGraphMode = .temperature
    @State private var locationName: String = ""
    private let weatherService = TodayWeatherService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(String(localized: "TodayWeather.Settings.Show", table: "Home"), isOn: $isWeatherEnabled)
                }

                if isWeatherEnabled {
                    Section {
                        NavigationLink {
                            TodayWeatherLocationPicker()
                        } label: {
                            LabeledContent(
                                String(localized: "TodayWeather.Settings.Location", table: "Home"),
                                value: locationName
                            )
                        }
                    }

                    Section {
                        Picker(
                            String(localized: "TodayWeather.Settings.Background", table: "Home"),
                            selection: $graphMode
                        ) {
                            ForEach(WeatherGraphMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.symbol).tag(mode)
                            }
                        }
                    }
                }
            }
            .settingsListStyle()
            .navigationTitle(String(localized: "TodayWeather.Settings.Title", table: "Home"))
            .inlineNavigationTitle()
            .compatibleSoftScrollEdgeEffectStyle()
            .toolbar {
                ToolbarItem(placement: .sheetTrailing) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                locationName = savedLocationName
            }
            .onChange(of: isWeatherEnabled) { _, isEnabled in
                if isEnabled {
                    Task { await weatherService.refreshIfNeeded() }
                }
            }
        }
    }

    private var savedLocationName: String {
        guard let savedLocation = weatherService.savedLocation, !savedLocation.isCurrent else {
            return String(localized: "TodayWeather.Location.Current", table: "Home")
        }
        return savedLocation.name
    }
}
