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
                Picker(String(localized: "YouTube.OpenMode", table: "Settings"), selection: $youTubeOpenMode) {
                    Text(String(localized: "YouTube.InAppPlayer", table: "Settings"))
                        .tag(YouTubeOpenMode.inAppPlayer)
                    if YouTubeHelper.isAppInstalled {
                        Text(String(localized: "YouTube.YouTubeApp", table: "Settings"))
                            .tag(YouTubeOpenMode.youTubeApp)
                    }
                    Text(String(localized: "YouTube.Browser", table: "Settings"))
                        .tag(YouTubeOpenMode.browser)
                }
            }

            if youTubeOpenMode == .inAppPlayer {
                Section {
                    if isYouTubeSignedIn {
                        Button(String(localized: "YouTubePlayer.SignOut", table: "Integrations")) {
                            Task {
                                await YouTubePlayerView.clearYouTubeSession()
                                isYouTubeSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "YouTubePlayer.SignIn", table: "Integrations")) {
                            showYouTubeLogin = true
                        }
                    }
                } footer: {
                    Text(String(localized: "YouTubePlayer.Footer", table: "Integrations"))
                }

                Section {
                    Toggle(
                        String(localized: "YouTube.SponsorBlock", table: "Settings"),
                        isOn: $sponsorBlockEnabled
                    )
                } footer: {
                    Text(String(localized: "YouTube.SponsorBlock.Footer", table: "Settings"))
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
                        Text(String(localized: "YouTube.SponsorBlock.Categories", table: "Settings"))
                    }
                }
            }
        }
        .animation(.smooth.speed(2.0), value: youTubeOpenMode)
        .navigationTitle(String(localized: "YouTube", table: "Integrations"))
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
