import SwiftUI

struct LabsView: View {

    @AppStorage("Labs.XProfileFeeds") private var xProfileFeedsEnabled: Bool = false
    @AppStorage("Labs.YouTubePlayer") private var youTubePlayerEnabled: Bool = false

    @State private var isXSignedIn = false
    @State private var showXLogin = false
    @State private var isYouTubeSignedIn = false
    @State private var showYouTubeLogin = false

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
                Toggle(String(localized: "Labs.XProfileFeeds"), isOn: $xProfileFeedsEnabled)

                if xProfileFeedsEnabled {
                    if isXSignedIn {
                        Button(String(localized: "Labs.XProfileFeeds.SignOut")) {
                            Task {
                                await XProfileScraper.clearXSession()
                                isXSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "Labs.XProfileFeeds.SignIn")) {
                            showXLogin = true
                        }
                    }
                }
            } footer: {
                Text("Labs.XProfileFeeds.Footer")
            }

            Section {
                Toggle(String(localized: "Labs.YouTubePlayer"), isOn: $youTubePlayerEnabled)

                if youTubePlayerEnabled {
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
                }
            } footer: {
                Text("Labs.YouTubePlayer.Footer")
            }
        }
        .navigationTitle(String(localized: "Labs.Title"))
        .toolbarTitleDisplayMode(.inlineLarge)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .sheet(isPresented: $showXLogin) {
            Task {
                isXSignedIn = await XProfileScraper.hasXSession()
            }
        } content: {
            XLoginView()
        }
        .sheet(isPresented: $showYouTubeLogin) {
            Task {
                isYouTubeSignedIn = await YouTubePlayerView.hasYouTubeSession()
            }
        } content: {
            YouTubeLoginView()
        }
        .task {
            isXSignedIn = await XProfileScraper.hasXSession()
            isYouTubeSignedIn = await YouTubePlayerView.hasYouTubeSession()
        }
    }
}
