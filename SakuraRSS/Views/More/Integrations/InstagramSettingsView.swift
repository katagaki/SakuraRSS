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
                Toggle(String(localized: "InstagramProfileFeeds", table: "Labs"),
                       isOn: $instagramProfileFeedsEnabled)

                if instagramProfileFeedsEnabled {
                    if isCheckingLogin {
                        ProgressView()
                    } else if isInstagramSignedIn {
                        Button(String(localized: "InstagramProfileFeeds.SignOut", table: "Labs")) {
                            Task {
                                await InstagramProfileScraper.clearInstagramSession()
                                isInstagramSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "InstagramProfileFeeds.SignIn", table: "Labs")) {
                            showInstagramLogin = true
                        }
                    }
                }
            } footer: {
                Text(String(localized: "InstagramProfileFeeds.Footer", table: "Labs"))
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
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .sheet(isPresented: $showInstagramLogin) {
            Task {
                isCheckingLogin = true
                isInstagramSignedIn = await InstagramProfileScraper.hasInstagramSession()
                isCheckingLogin = false
            }
        } content: {
            InstagramLoginView()
        }
        .task {
            isInstagramSignedIn = await InstagramProfileScraper.hasInstagramSession()
            isCheckingLogin = false
        }
    }
}
