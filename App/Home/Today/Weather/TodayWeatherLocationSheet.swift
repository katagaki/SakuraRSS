import SwiftUI

struct TodayWeatherLocationSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TodayWeatherLocationPicker()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .cancel) { dismiss() }
                    }
                }
        }
    }
}
