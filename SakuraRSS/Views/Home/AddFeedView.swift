import SwiftUI

struct AddFeedView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    var initialURL: String = ""
    var onFeedAdded: ((String) -> Void)?

    @State private var urlInput = ""
    @State private var discoveredFeeds: [DiscoveredFeed] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var addedURLs: Set<String> = []
    @State private var showXLogin = false
    @State private var pendingXFeed: DiscoveredFeed?
    @State private var suggestedTopics: [SuggestedTopic] = []
    @FocusState private var isURLFieldFocused: Bool

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sakura"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "AddFeed.DomainPlaceholder"), text: $urlInput)
                        .focused($isURLFieldFocused)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { searchFeeds() }
                        .overlay(alignment: .trailing) {
                            if urlInput.isEmpty {
                                PasteButton(payloadType: URL.self) { urls in
                                    if let url = urls.first {
                                        urlInput = url.absoluteString
                                    }
                                }
                                .buttonBorderShape(.capsule)
                                .controlSize(.mini)
                            }
                        }

                    Button {
                        searchFeeds()
                    } label: {
                        HStack {
                            Text("AddFeed.Search")
                            if isSearching {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(urlInput.isEmpty || isSearching)
                } header: {
                    Text("AddFeed.Section.Search")
                } footer: {
                    Text("AddFeed.Section.SearchFooter.\(appName)")
                }

                if urlInput.isEmpty {
                    ForEach(suggestedTopics, id: \.title) { topic in
                        Section {
                            ForEach(topic.sites, id: \.feedUrl) { site in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(site.title)
                                            .lineLimit(1)
                                        Text(site.feedUrl)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if addedURLs.contains(site.feedUrl) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.green)
                                    } else {
                                        Button {
                                            addSuggestedFeed(site)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        } header: {
                            Text(localizedTopicTitle(topic.title))
                        }
                    }

                    RSSDiscoverySection()
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if !discoveredFeeds.isEmpty {
                    Section {
                        ForEach(discoveredFeeds) { feed in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feed.title)
                                        .lineLimit(1)
                                    Text(displayURL(for: feed))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if addedURLs.contains(feed.url) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                } else {
                                    Button {
                                        addFeed(feed)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    } header: {
                        Text("AddFeed.Section.Discovered")
                    }
                }
            }
            .animation(.smooth.speed(2.0), value: urlInput.isEmpty)
            .navigationTitle(String(localized: "AddFeed.Title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled()
            .sheet(isPresented: $showXLogin) {
                if let pending = pendingXFeed {
                    addFeedAfterXLogin(pending)
                }
            } content: {
                XLoginView()
            }
            .onAppear {
                suggestedTopics = SuggestedFeedsLoader.topicsForCurrentRegion()
                if !initialURL.isEmpty {
                    urlInput = initialURL
                    searchFeeds()
                } else {
                    isURLFieldFocused = true
                }
            }
        }
    }

    private func searchFeeds() {
        isSearching = true
        errorMessage = nil
        discoveredFeeds = []

        Task {
            var results: [DiscoveredFeed] = []

            // 1. Try as direct feed URL (highest priority)
            if let feed = await tryDirectFeedURL(urlInput) {
                results.append(feed)
            }

            // 2. Search for feeds on the full URL
            let normalizedURL = normalizeURL(urlInput)
            if let url = URL(string: normalizedURL) {
                let urlFeeds = await FeedDiscovery.shared.discoverFeeds(fromPageURL: url)
                results.append(contentsOf: urlFeeds)
            }

            // 3. Fall back to root domain search if nothing found yet
            if results.isEmpty {
                let domain = extractDomain(from: urlInput)
                let domainFeeds = await FeedDiscovery.shared.discoverFeeds(forDomain: domain)
                results.append(contentsOf: domainFeeds)
            }

            // Deduplicate by URL, keeping the first (highest priority) occurrence
            var seen = Set<String>()
            results = results.filter { seen.insert($0.url).inserted }

            // Sort alphabetically by title
            results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            await MainActor.run {
                withAnimation(.smooth.speed(2.0)) {
                    isSearching = false
                    if results.isEmpty {
                        errorMessage = String(localized: "AddFeed.NoFeedsFound")
                    } else {
                        discoveredFeeds = results
                    }
                }
            }
        }
    }

    private func tryDirectFeedURL(_ input: String) async -> DiscoveredFeed? {
        let urlString = normalizeURL(input)
        guard let url = URL(string: urlString) else { return nil }
        let fetchURL = RedirectDomains.redirectedURL(url)

        do {
            let (data, response) = try await URLSession.shared.data(from: fetchURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let parser = RSSParser()
            guard let parsed = parser.parse(data: data) else { return nil }

            let siteURL = parsed.siteURL.isEmpty ? urlString : parsed.siteURL
            let title = parsed.title.isEmpty ? (url.host ?? urlString) : parsed.title
            return DiscoveredFeed(title: title, url: urlString, siteURL: siteURL)
        } catch {
            return nil
        }
    }

    private func addFeed(_ discovered: DiscoveredFeed) {
        // X feeds require the experiment to be enabled
        guard !XProfileScraper.isXFeedURL(discovered.url)
                || UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") else {
            return
        }
        // If this is an X feed and the user hasn't logged in yet, prompt login first
        if XProfileScraper.isXFeedURL(discovered.url) && !feedManager.hasXFeeds {
            pendingXFeed = discovered
            Task {
                let hasSession = await XProfileScraper.hasXSession()
                if hasSession {
                    addFeedDirectly(discovered)
                } else {
                    showXLogin = true
                }
            }
            return
        }
        addFeedDirectly(discovered)
    }

    private func addFeedDirectly(_ discovered: DiscoveredFeed) {
        do {
            try feedManager.addFeed(
                url: discovered.url,
                title: discovered.title,
                siteURL: discovered.siteURL
            )
            addedURLs.insert(discovered.url)
            onFeedAdded?(discovered.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addFeedAfterXLogin(_ discovered: DiscoveredFeed) {
        Task {
            let hasSession = await XProfileScraper.hasXSession()
            if hasSession {
                addFeedDirectly(discovered)
            }
            pendingXFeed = nil
        }
    }

    private func normalizeURL(_ input: String) -> String {
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            return input
        }
        return "https://" + input
    }

    private func extractDomain(from input: String) -> String {
        var cleaned = input
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        if let slashIndex = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[cleaned.startIndex..<slashIndex])
        }
        return cleaned
    }

    /// Shows the site URL for X feeds instead of the internal x-profile:// scheme.
    private func displayURL(for feed: DiscoveredFeed) -> String {
        if XProfileScraper.isXFeedURL(feed.url) {
            return feed.siteURL
        }
        return feed.url
    }

    private func addSuggestedFeed(_ site: SuggestedSite) {
        do {
            try feedManager.addFeed(
                url: site.feedUrl,
                title: site.title,
                siteURL: ""
            )
            addedURLs.insert(site.feedUrl)
            onFeedAdded?(site.feedUrl)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func localizedTopicTitle(_ title: String) -> String {
        switch title {
        case "Headlines": String(localized: "SuggestedFeeds.Topic.Headlines")
        case "Technology": String(localized: "SuggestedFeeds.Topic.Technology")
        case "Science": String(localized: "SuggestedFeeds.Topic.Science")
        case "Economics": String(localized: "SuggestedFeeds.Topic.Economics")
        case "Business": String(localized: "SuggestedFeeds.Topic.Business")
        case "Sports": String(localized: "SuggestedFeeds.Topic.Sports")
        case "Politics": String(localized: "SuggestedFeeds.Topic.Politics")
        case "Weather": String(localized: "SuggestedFeeds.Topic.Weather")
        default: title
        }
    }
}
