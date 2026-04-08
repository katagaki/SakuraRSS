import SwiftUI

struct InstagramSettingsView: View {

    @AppStorage("Labs.InstagramProfileFeeds") private var instagramProfileFeedsEnabled: Bool = false
    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false

    @State private var isInstagramSignedIn = false
    @State private var showInstagramLogin = false

    var body: some View {
        List {
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

            if instagramProfileFeedsEnabled {
                Section {
                    Toggle(String(localized: "Instagram.HideReels"), isOn: $hideReels)
                } footer: {
                    Text("Instagram.HideReels.Footer")
                }
            }
        }
        .animation(.smooth.speed(2.0), value: instagramProfileFeedsEnabled)
        .navigationTitle(String(localized: "Integrations.Instagram"))
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .sheet(isPresented: $showInstagramLogin) {
            Task {
                isInstagramSignedIn = await InstagramProfileScraper.hasInstagramSession()
            }
        } content: {
            InstagramLoginView()
        }
        .task {
            isInstagramSignedIn = await InstagramProfileScraper.hasInstagramSession()
        }
    }
}
