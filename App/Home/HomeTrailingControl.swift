import SwiftUI
import Hanami

struct HomeTrailingControl: View {

    let selectionStore: HomeSelectionStore
    let usesPhoneTopBarRedesign: Bool
    @Binding var showingWeatherLocationPicker: Bool
    let sectionDisplayMenu: HomeSectionDisplayMenuModel
    @AppStorage("Today.Weather.GraphMode") private var weatherGraphMode: WeatherGraphMode = .temperature

    private var isTodaySelected: Bool {
        if case .section(.today) = selectionStore.selection { return true }
        return false
    }

    var body: some View {
        if usesPhoneTopBarRedesign {
            Menu {
                menuContent
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .menuActionDismissBehavior(isTodaySelected ? .automatic : .disabled)
        } else if isTodaySelected {
            WeatherToolbarButton(
                isLocationPickerPresented: $showingWeatherLocationPicker
            )
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if isTodaySelected {
            Picker(
                String(localized: "TodayWeather.Graph", table: "Home"),
                selection: $weatherGraphMode
            ) {
                ForEach(WeatherGraphMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
            Button {
                showingWeatherLocationPicker = true
            } label: {
                Label(
                    String(localized: "TodayWeather.Location.Title", table: "Home"),
                    systemImage: "location"
                )
            }
        } else if let binding = sectionDisplayMenu.styleBinding {
            DisplayStylePicker(
                displayStyle: binding,
                hasImages: sectionDisplayMenu.hasImages,
                showTimeline: sectionDisplayMenu.showTimeline,
                showPodcast: sectionDisplayMenu.showPodcast
            )
        }
    }
}
