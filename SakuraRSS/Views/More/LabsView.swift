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
                Text("Labs.Warning \(appName)")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Labs.XProfileFeeds", isOn: $xProfileFeedsEnabled)

                if xProfileFeedsEnabled {
                    if isXSignedIn {
                        Button("Labs.XProfileFeeds.RefreshAuth") {
                            Task {
                                await MainActor.run {
                                    XProfileScraper.queryIDsFetched = false
                                }
                                await XProfileScraper.fetchQueryIDsIfNeeded()
                            }
                        }
                        Button("Labs.XProfileFeeds.SignOut") {
                            Task {
                                await XProfileScraper.clearXSession()
                                isXSignedIn = false
                            }
                        }
                    } else {
                        Button("Labs.XProfileFeeds.SignIn") {
                            showXLogin = true
                        }
                    }
                }
            } footer: {
                Text("Labs.XProfileFeeds.Footer")
            }

            Section {
                Toggle("Labs.PetalRecipes", isOn: $petalRecipesEnabled)

                if petalRecipesEnabled {
                    NavigationLink("Petal.Manage.Title") {
                        PetalManagementView()
                    }
                }
            } footer: {
                Text("Labs.PetalRecipes.Footer")
            }

            Section {
                Toggle("Labs.InstagramProfileFeeds",
                       isOn: $instagramProfileFeedsEnabled)

                if instagramProfileFeedsEnabled {
                    if isInstagramSignedIn {
                        Button("Labs.InstagramProfileFeeds.SignOut") {
                            Task {
                                await InstagramProfileScraper.clearInstagramSession()
                                isInstagramSignedIn = false
                            }
                        }
                    } else {
                        Button("Labs.InstagramProfileFeeds.SignIn") {
                            showInstagramLogin = true
                        }
                    }
                }
            } footer: {
                Text("Labs.InstagramProfileFeeds.Footer")
            }

        }
        .animation(.smooth.speed(2.0), value: xProfileFeedsEnabled)
        .animation(.smooth.speed(2.0), value: instagramProfileFeedsEnabled)
        .animation(.smooth.speed(2.0), value: petalRecipesEnabled)
        .navigationTitle("Labs.Title")
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
