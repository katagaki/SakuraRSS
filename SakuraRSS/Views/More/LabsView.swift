import SwiftUI

struct LabsView: View {

    @AppStorage("Labs.XProfileFeeds") private var xProfileFeedsEnabled: Bool = false
    @AppStorage("Labs.InstagramProfileFeeds") private var instagramProfileFeedsEnabled: Bool = false
    @AppStorage("Labs.PetalRecipes") private var petalRecipesEnabled: Bool = false

    @State private var isXSignedIn = false
    @State private var showXLogin = false
    @State private var isInstagramSignedIn = false
    @State private var showInstagramLogin = false

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sakura"
    }

    var body: some View {
        List {
            Section {
                Text(String(localized: "Warning \(appName)", table: "Labs"))
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .listRowBackground(Color.clear)
            }

            Section {
                Toggle(String(localized: "PetalRecipes", table: "Labs"), isOn: $petalRecipesEnabled)

                if petalRecipesEnabled {
                    NavigationLink(String(localized: "Manage.Title", table: "Petal")) {
                        PetalManagementView()
                    }
                }
            } footer: {
                Text(String(localized: "PetalRecipes.Footer", table: "Labs"))
            }
        }
        .animation(.smooth.speed(2.0), value: xProfileFeedsEnabled)
        .animation(.smooth.speed(2.0), value: instagramProfileFeedsEnabled)
        .animation(.smooth.speed(2.0), value: petalRecipesEnabled)
        .navigationTitle(String(localized: "Title", table: "Labs"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showXLogin) {
            Task {
                isXSignedIn = await XProfileScraper.hasXSession()
            }
        } content: {
            XLoginView()
        }
        .sheet(isPresented: $showInstagramLogin) {
            Task {
                isInstagramSignedIn = await InstagramProfileScraper.hasInstagramSession()
            }
        } content: {
            InstagramLoginView()
        }
        .task {
            isXSignedIn = await XProfileScraper.hasXSession()
            isInstagramSignedIn = await InstagramProfileScraper.hasInstagramSession()
        }
    }
}
