import SwiftUI

struct XSettingsView: View {

    @AppStorage("Labs.XProfileFeeds") private var xProfileFeedsEnabled: Bool = false

    @State private var isCheckingLogin = true
    @State private var isXSignedIn = false
    @State private var showXLogin = false

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "XProfileFeeds", table: "Integrations"), isOn: $xProfileFeedsEnabled)

                if xProfileFeedsEnabled {
                    if isCheckingLogin {
                        ProgressView()
                    } else if isXSignedIn {
                        Button(String(localized: "XProfileFeeds.RefreshAuth", table: "Integrations")) {
                            Task {
                                await MainActor.run {
                                    XProfileScraper.queryIDsFetched = false
                                }
                                await XProfileScraper.fetchQueryIDsIfNeeded()
                            }
                        }
                        Button(String(localized: "XProfileFeeds.SignOut", table: "Integrations")) {
                            Task {
                                await XProfileScraper.clearXSession()
                                isXSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "XProfileFeeds.SignIn", table: "Integrations")) {
                            showXLogin = true
                        }
                    }
                }
            } footer: {
                Text(String(localized: "XProfileFeeds.Footer", table: "Integrations"))
            }
        }
        .animation(.smooth.speed(2.0), value: xProfileFeedsEnabled)
        .navigationTitle(String(localized: "X", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
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
