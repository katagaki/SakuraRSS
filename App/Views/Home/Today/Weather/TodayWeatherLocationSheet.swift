import SwiftUI
import MapKit

struct TodayWeatherLocationSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var service: TodayWeatherService = .shared
    @State private var query: String = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var isSearching: Bool = false
    @State private var completer = MKLocalSearchCompleter()
    @State private var completerDelegate = LocationCompleterDelegate()
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task {
                            await service.setLocation(TodayWeatherLocation(
                                name: String(localized: "TodayWeather.Location.Current", table: "Home"),
                                latitude: nil,
                                longitude: nil
                            ))
                            dismiss()
                        }
                    } label: {
                        Label {
                            Text(String(localized: "TodayWeather.Location.Current", table: "Home"))
                        } icon: {
                            Image(systemName: "location.fill")
                        }
                    }
                }

                if !results.isEmpty {
                    Section {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                            Button {
                                Task { await select(result) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(String(localized: "TodayWeather.Location.Results", table: "Home"))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(String(localized: "TodayWeather.Location.SearchPlaceholder", table: "Home"))
            )
            .navigationTitle(String(localized: "TodayWeather.Location.Title", table: "Home"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .cancel) { dismiss() }
                }
            }
            .onAppear {
                completer.resultTypes = [.address, .pointOfInterest]
                completer.delegate = completerDelegate
                completerDelegate.didUpdate = { suggestions in
                    Task { @MainActor in
                        self.results = suggestions
                    }
                }
            }
            .onChange(of: query) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                debounceTask?.cancel()
                if trimmed.isEmpty {
                    results = []
                    return
                }
                debounceTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    completer.queryFragment = trimmed
                }
            }
            .onDisappear {
                debounceTask?.cancel()
            }
        }
    }

    private func select(_ result: MKLocalSearchCompletion) async {
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let item = response.mapItems.first else { return }
        let coordinate = item.placemark.coordinate
        let name = result.title.isEmpty ? (item.name ?? "") : result.title
        await service.setLocation(TodayWeatherLocation(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
        dismiss()
    }
}

private final class LocationCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    var didUpdate: (([MKLocalSearchCompletion]) -> Void)?

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        didUpdate?(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        didUpdate?([])
    }
}
