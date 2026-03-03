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
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "AddFeed.URLPlaceholder"), text: $urlInput)
                        .focused($isURLFieldFocused)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { searchFeeds() }

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
                    HStack {
                        Text("AddFeed.Section.Search")
                        Spacer()
                        if urlInput.isEmpty {
                            PasteButton(payloadType: URL.self) { urls in
                                if let url = urls.first {
                                    urlInput = url.absoluteString
                                }
                            }
                            .buttonStyle(.plain)
                            .buttonBorderShape(.capsule)
                            .controlSize(.mini)
                        }
                    }
                } footer: {
                    Text("AddFeed.Section.SearchFooter")
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
                                    Text(feed.url)
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
            .onAppear {
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
            // 1. Try as direct feed URL
            let directResult = await tryDirectFeedURL(urlInput)
            if let feed = directResult {
                isSearching = false
                discoveredFeeds = [feed]
                return
            }

            // 2. Search for feeds on the full URL
            let normalizedURL = normalizeURL(urlInput)
            if let url = URL(string: normalizedURL) {
                let urlFeeds = await FeedDiscovery.shared.discoverFeeds(fromPageURL: url)
                if !urlFeeds.isEmpty {
                    isSearching = false
                    discoveredFeeds = urlFeeds
                    return
                }
            }

            // 3. Fall back to root domain search
            let domain = extractDomain(from: urlInput)
            let domainFeeds = await FeedDiscovery.shared.discoverFeeds(forDomain: domain)
            isSearching = false
            if domainFeeds.isEmpty {
                errorMessage = String(localized: "AddFeed.NoFeedsFound")
            } else {
                discoveredFeeds = domainFeeds
            }
        }
    }

    private func tryDirectFeedURL(_ input: String) async -> DiscoveredFeed? {
        let urlString = normalizeURL(input)
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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
}
