import SwiftUI

struct XSettingsView: View {

    @AppStorage("Labs.XProfileFeeds") private var xProfileFeedsEnabled: Bool = false

    @State private var isCheckingLogin = true
    @State private var isXSignedIn = false
    @State private var showXLogin = false

    var body: some View {
        List {
            Section {
                Toggle("Labs.XProfileFeeds", isOn: $xProfileFeedsEnabled)

                if xProfileFeedsEnabled {
                    if isCheckingLogin {
                        ProgressView()
                    } else if isXSignedIn {
                        Button("Labs.XProfileFeeds.RefreshAuth") {
                            Task {
                                await MainActor.run {
                                    XIntegration.queryIDsFetched = false
                                }
                                await XIntegration.fetchQueryIDsIfNeeded()
                            }
                        }
                        Button("Labs.XProfileFeeds.SignOut") {
                            Task {
                                await XIntegration.clearSession()
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
        }
        .animation(.smooth.speed(2.0), value: xProfileFeedsEnabled)
        .navigationTitle("Integrations.X")
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showXLogin) {
            Task {
                isCheckingLogin = true
                isXSignedIn = await XIntegration.hasSession()
                isCheckingLogin = false
            }
        } content: {
            XLoginView()
        }
        .task {
            isXSignedIn = await XIntegration.hasSession()
            isCheckingLogin = false
        }
    }
}
