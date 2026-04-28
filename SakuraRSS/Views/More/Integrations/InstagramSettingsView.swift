import SwiftUI

struct InstagramSettingsView: View {

    @AppStorage("Labs.InstagramProfileFeeds") private var instagramProfileFeedsEnabled: Bool = false
    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false

    @State private var isCheckingLogin = true
    @State private var isInstagramSignedIn = false
    @State private var showInstagramLogin = false

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "InstagramProfileFeeds", table: "Integrations"),
                       isOn: $instagramProfileFeedsEnabled)

                if instagramProfileFeedsEnabled {
                    if isCheckingLogin {
                        ProgressView()
                    } else if isInstagramSignedIn {
                        Button(String(localized: "InstagramProfileFeeds.SignOut", table: "Integrations")) {
                            Task {
                                await InstagramProfileFetcher.clearSession()
                                isInstagramSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "InstagramProfileFeeds.SignIn", table: "Integrations")) {
                            showInstagramLogin = true
                        }
                    }
                }
            } footer: {
                Text(String(localized: "InstagramProfileFeeds.Footer", table: "Integrations"))
            }

            if instagramProfileFeedsEnabled {
                Section {
                    Toggle(String(localized: "Instagram.HideReels", table: "Integrations"), isOn: $hideReels)
                } footer: {
                    Text(String(localized: "Instagram.HideReels.Footer", table: "Integrations"))
                }
            }
        }
        .animation(.smooth.speed(2.0), value: instagramProfileFeedsEnabled)
        .navigationTitle(String(localized: "Instagram", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
        .sheet(isPresented: $showInstagramLogin) {
            Task {
                isCheckingLogin = true
                isInstagramSignedIn = InstagramProfileFetcher.hasSession()
                isCheckingLogin = false
            }
        } content: {
            InstagramLoginView()
        }
        .task {
            isInstagramSignedIn = InstagramProfileFetcher.hasSession()
            isCheckingLogin = false
        }
    }
}
