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
                Toggle("Labs.XProfileFeeds", isOn: $xProfileFeedsEnabled)

                if xProfileFeedsEnabled {
                    if isXSignedIn {
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

            Section {
                Toggle("Labs.InstagramProfileFeeds",
                       isOn: $instagramProfileFeedsEnabled)

                if instagramProfileFeedsEnabled {
                    if isInstagramSignedIn {
                        Button("Labs.InstagramProfileFeeds.SignOut") {
                            Task {
                                await InstagramIntegration.clearSession()
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
        .navigationTitle("Labs.Title")
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showXLogin) {
            Task {
                isXSignedIn = await XIntegration.hasSession()
            }
        } content: {
            XLoginView()
        }
        .sheet(isPresented: $showInstagramLogin) {
            Task {
                isInstagramSignedIn = await InstagramIntegration.hasSession()
            }
        } content: {
            InstagramLoginView()
        }
        .task {
            isXSignedIn = await XIntegration.hasSession()
            isInstagramSignedIn = await InstagramIntegration.hasSession()
        }
    }
}
