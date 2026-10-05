import Hanami
import SwiftUI

struct AddFeedSheet: View {

    let feedManager: FeedManager
    let onDone: () -> Void
    @State var session: FeedDiscoverySession
    @State private var input = ""
    @State private var isGeneratingWebFeed = false
    @AppStorage("Labs.PetalRecipes") private var webFeedsEnabled = false

    private var subscribedURLs: Set<String> {
        Set(feedManager.feeds.map(\.url))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "AddFeed.Title", table: "Feeds"))
                .font(.title2)
                .fontWeight(.bold)
            HStack {
                TextField(String(localized: "AddFeed.URLPlaceholder", table: "Feeds"), text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(search)
                Button(String(localized: "AddFeed.Search", table: "Feeds"), action: search)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || session.isSearching)
            }
            content
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 360)
            HStack {
                if webFeedsEnabled {
                    Button(String(localized: "AddFeed.Generate", table: "Petal")) { isGeneratingWebFeed = true }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Spacer()
                Button(String(localized: "Shared.Done"), action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
        .sheet(isPresented: $isGeneratingWebFeed) {
            PetalBuilderView(mode: .create(initialURL: BrowserAddressInput.normalizedURLString(from: input) ?? input))
                .environment(feedManager)
                .frame(minWidth: 600, minHeight: 640)
        }
        .onAppear {
            guard !session.urlString.isEmpty else { return }
            input = BrowserAddressInput.displayString(for: session.urlString)
            search()
        }
    }

    private func search() {
        let query = input
        Task { await session.search(query) }
    }

    @ViewBuilder
    private var content: some View {
        if session.isSearching {
            VStack(spacing: 10) {
                ProgressView()
                Text(String(localized: "AddFeed.Extension.Searching", table: "Feeds"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !session.hasSearched {
            Text(String(localized: "AddFeed.Section.SearchFooter.\(MainMenuBuilder.applicationName)", table: "Feeds"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if session.discoveredFeeds.isEmpty {
            Text(session.errorMessage ?? "")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section(String(localized: "AddFeed.Section.Discovered", table: "Feeds")) {
                    ForEach(session.discoveredFeeds) { feed in
                        DiscoveredFeedRow(
                            feed: feed,
                            isSubscribed: session.addedURLs.contains(feed.url) || subscribedURLs.contains(feed.url),
                            isAdding: session.addingURLs.contains(feed.url),
                            canAdd: session.canAdd(feed)
                        ) {
                            Task { await session.add(feed, to: feedManager) }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}
