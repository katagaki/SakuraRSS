import SwiftUI

struct LabsView: View {

    @AppStorage("Labs.XProfileFeeds") private var xProfileFeedsEnabled: Bool = false
    @AppStorage("Labs.InstagramProfileFeeds") private var instagramProfileFeedsEnabled: Bool = false

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
                Toggle(String(localized: "Labs.XProfileFeeds"), isOn: $xProfileFeedsEnabled)

                if xProfileFeedsEnabled {
                    if isXSignedIn {
                        Button(String(localized: "Labs.XProfileFeeds.RefreshAuth")) {
                            Task {
                                await MainActor.run {
                                    XProfileScraper.queryIDsFetched = false
                                }
                                await XProfileScraper.fetchQueryIDsIfNeeded()
                            }
                        }
                        Button(String(localized: "Labs.XProfileFeeds.SignOut")) {
                            Task {
                                await XProfileScraper.clearXSession()
                                isXSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "Labs.XProfileFeeds.SignIn")) {
                            showXLogin = true
                        }
                    }
                }
            } footer: {
                Text("Labs.XProfileFeeds.Footer")
            }

            Section {
                Toggle(String(localized: "Labs.InstagramProfileFeeds"),
                       isOn: $instagramProfileFeedsEnabled)

                if instagramProfileFeedsEnabled {
                    if isInstagramSignedIn {
                        Button(String(localized: "Labs.InstagramProfileFeeds.SignOut")) {
                            Task {
                                await InstagramProfileScraper.clearInstagramSession()
                                isInstagramSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "Labs.InstagramProfileFeeds.SignIn")) {
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
        .navigationTitle(String(localized: "Labs.Title"))
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
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
