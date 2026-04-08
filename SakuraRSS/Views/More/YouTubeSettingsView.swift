import SwiftUI

struct YouTubeSettingsView: View {

    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @AppStorage("YouTube.SponsorBlock.Enabled") private var sponsorBlockEnabled = false
    @AppStorage("YouTube.SponsorBlock.Categories") private var sponsorBlockCategories = "sponsor,selfpromo,interaction"

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

                Section {
                    Toggle(
                        String(localized: "Settings.YouTube.SponsorBlock"),
                        isOn: $sponsorBlockEnabled
                    )
                } footer: {
                    Text("Settings.YouTube.SponsorBlock.Footer")
                }

                if sponsorBlockEnabled {
                    Section {
                        ForEach(SponsorBlockCategory.allCases, id: \.rawValue) { category in
                            Toggle(category.displayName, isOn: Binding(
                                get: {
                                    sponsorBlockCategories
                                        .split(separator: ",")
                                        .map(String.init)
                                        .contains(category.rawValue)
                                },
                                set: { enabled in
                                    var cats = sponsorBlockCategories
                                        .split(separator: ",")
                                        .map(String.init)
                                        .filter { !$0.isEmpty }
                                    if enabled {
                                        if !cats.contains(category.rawValue) {
                                            cats.append(category.rawValue)
                                        }
                                    } else {
                                        cats.removeAll { $0 == category.rawValue }
                                    }
                                    sponsorBlockCategories = cats.joined(separator: ",")
                                }
                            ))
                        }
                    } header: {
                        Text("Settings.YouTube.SponsorBlock.Categories")
                    }
                }
            }
        }
        .animation(.smooth.speed(2.0), value: youTubeOpenMode)
        .navigationTitle(String(localized: "Integrations.YouTube"))
        .toolbarTitleDisplayMode(.inline)
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
