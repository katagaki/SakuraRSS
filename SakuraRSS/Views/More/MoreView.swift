import SwiftUI
import FoundationModels

struct MoreView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("BackgroundRefresh.Interval") private var refreshInterval: Int = 60
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("TodaysSummary.Enabled") private var todaysSummaryEnabled: Bool = true
    @AppStorage("WhileYouSlept.Enabled") private var whileYouSleptEnabled: Bool = true
    #if DEBUG
    @AppStorage("Debug.ForceWhileYouSlept") private var forceWhileYouSlept: Bool = false
    @AppStorage("Debug.ForceTodaysSummary") private var forceTodaysSummary: Bool = false
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    #endif

    private var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "Settings.DisplayStyle"), selection: $defaultDisplayStyle) {
                        Text("Articles.Style.Inbox")
                            .tag(FeedDisplayStyle.inbox)
                        Text("Articles.Style.Feed")
                            .tag(FeedDisplayStyle.feed)
                        Text("Articles.Style.Magazine")
                            .tag(FeedDisplayStyle.magazine)
                        Text("Articles.Style.Compact")
                            .tag(FeedDisplayStyle.compact)
                        Text("Articles.Style.Photos")
                            .tag(FeedDisplayStyle.photos)
                    }
                    Picker(String(localized: "Settings.SearchDisplayStyle"), selection: $searchDisplayStyle) {
                        Text("Articles.Style.Inbox")
                            .tag(FeedDisplayStyle.inbox)
                        Text("Articles.Style.Feed")
                            .tag(FeedDisplayStyle.feed)
                        Text("Articles.Style.Magazine")
                            .tag(FeedDisplayStyle.magazine)
                        Text("Articles.Style.Compact")
                            .tag(FeedDisplayStyle.compact)
                        Text("Articles.Style.Photos")
                            .tag(FeedDisplayStyle.photos)
                    }
                } header: {
                    Text("Settings.Section.Display")
                }

                Section {
                    Toggle(String(localized: "Settings.BackgroundRefresh"), isOn: $backgroundRefreshEnabled)
                    if backgroundRefreshEnabled {
                        Picker(String(localized: "Settings.RefreshInterval"), selection: $refreshInterval) {
                            Text("Settings.Refresh.15min").tag(15)
                            Text("Settings.Refresh.30min").tag(30)
                            Text("Settings.Refresh.1hour").tag(60)
                            Text("Settings.Refresh.4hours").tag(240)
                        }
                    }
                } header: {
                    Text("Settings.Section.Refresh")
                }

                if isAppleIntelligenceAvailable {
                    Section {
                        Toggle(String(localized: "Settings.WhileYouSlept"), isOn: $whileYouSleptEnabled)
                        Toggle(String(localized: "Settings.TodaysSummary"), isOn: $todaysSummaryEnabled)
                    } header: {
                        Text("Settings.Section.AppleIntelligence")
                    } footer: {
                        Text("Settings.AppleIntelligence.Footer")
                    }
                }

                #if DEBUG
                Section {
                    Toggle(isOn: $forceWhileYouSlept) {
                        Text(verbatim: "Force While You Slept")
                    }
                    Toggle(isOn: $forceTodaysSummary) {
                        Text(verbatim: "Force Today's Summary")
                    }
                    Button {
                        onboardingCompleted = false
                    } label: {
                        Text(verbatim: "Show Onboarding on Next Launch")
                    }
                } header: {
                    Text(verbatim: "Debug")
                }
                #endif

                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/SakuraRSS")!) {
                        HStack {
                            Text("More.SourceCode")
                            Spacer()
                            Text("katagaki/SakuraRSS")
                                .foregroundStyle(.secondary)
                            Image(systemName: "safari")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    NavigationLink(String(localized: "More.Attribution")) {
                        AttributesView()
                    }
                }
            }
            .navigationTitle(String(localized: "Tabs.More"))
            .scrollContentBackground(.hidden)
            .sakuraBackground()
        }
    }
}
