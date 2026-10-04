import Hanami
import SwiftUI

struct WebFeedsIntegrationSettings: View {

    @AppStorage("Labs.PetalRecipes") private var webFeedsEnabled = false
    @Environment(FeedManager.self) private var feedManager
    @State private var isManagingWebFeeds = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(IntegrationText.string("Petal"), isOn: $webFeedsEnabled)
            SettingsNote(text: IntegrationText.string("Petal.Footer"))
            Button(String(localized: "Manage.Title", table: "Petal") + "…") { isManagingWebFeeds = true }
                .disabled(!webFeedsEnabled)
                .padding(.top, 4)
        }
        .sheet(isPresented: $isManagingWebFeeds) {
            NavigationStack {
                PetalSettingsView()
                    .formStyle(.grouped)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Shared.Done")) { isManagingWebFeeds = false }
                        }
                    }
            }
            .environment(feedManager)
            .frame(width: 560, height: 560)
        }
    }
}
