import SwiftUI

struct XSettingsView: View {

    @AppStorage("Labs.XProfileFeeds") private var xProfileFeedsEnabled: Bool = false

    @State private var isCheckingLogin = true
    @State private var isXSignedIn = false
    @State private var showXLogin = false

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "XProfileFeeds", table: "Labs"), isOn: $xProfileFeedsEnabled)

                if xProfileFeedsEnabled {
                    if isCheckingLogin {
                        ProgressView()
                    } else if isXSignedIn {
                        Button(String(localized: "XProfileFeeds.RefreshAuth", table: "Labs")) {
                            Task {
                                await MainActor.run {
                                    XProfileScraper.queryIDsFetched = false
                                }
                                await XProfileScraper.fetchQueryIDsIfNeeded()
                            }
                        }
                        Button(String(localized: "XProfileFeeds.SignOut", table: "Labs")) {
                            Task {
                                await XProfileScraper.clearXSession()
                                isXSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "XProfileFeeds.SignIn", table: "Labs")) {
                            showXLogin = true
                        }
                    }
                }
            } footer: {
                Text(String(localized: "XProfileFeeds.Footer", table: "Labs"))
            }
        }
        .animation(.smooth.speed(2.0), value: xProfileFeedsEnabled)
        .navigationTitle(String(localized: "X", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .sheet(isPresented: $showXLogin) {
            Task {
                isCheckingLogin = true
                isXSignedIn = await XProfileScraper.hasXSession()
                isCheckingLogin = false
            }
        } content: {
            XLoginView()
        }
        .task {
            isXSignedIn = await XProfileScraper.hasXSession()
            isCheckingLogin = false
        }
    }
}
