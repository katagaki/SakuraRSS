import SwiftUI

struct YouTubeSettingsView: View {

    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    @State private var isYouTubeSignedIn = false
    @State private var showYouTubeLogin = false

    var body: some View {
        List {
            Section {
                Picker(String(localized: "Settings.YouTube.OpenMode"), selection: $youTubeOpenMode) {
                    Text("Settings.YouTube.InAppPlayer")
                        .tag(YouTubeOpenMode.inAppPlayer)
                    if YouTubeHelper.isAppInstalled {
                        Text("Settings.YouTube.YouTubeApp")
                            .tag(YouTubeOpenMode.youTubeApp)
                    }
                    Text("Settings.YouTube.Browser")
                        .tag(YouTubeOpenMode.browser)
                }
            }

            if youTubeOpenMode == .inAppPlayer {
                Section {
                    if isYouTubeSignedIn {
                        Button(String(localized: "Labs.YouTubePlayer.SignOut")) {
                            Task {
                                await YouTubePlayerView.clearYouTubeSession()
                                isYouTubeSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "Labs.YouTubePlayer.SignIn")) {
                            showYouTubeLogin = true
                        }
                    }
                } footer: {
                    Text("Labs.YouTubePlayer.Footer")
                }
            }
        }
        .animation(.smooth.speed(2.0), value: youTubeOpenMode)
        .navigationTitle(String(localized: "Integrations.YouTube"))
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .sheet(isPresented: $showYouTubeLogin) {
            Task {
                isYouTubeSignedIn = await YouTubePlayerView.hasYouTubeSession()
            }
        } content: {
            YouTubeLoginView()
        }
        .task {
            isYouTubeSignedIn = await YouTubePlayerView.hasYouTubeSession()
        }
    }
}
