import SwiftUI

struct AddFeedView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    @State private var domainOrURL = ""
    @State private var discoveredFeeds: [DiscoveredFeed] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var addedURLs: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "AddFeed.DomainPlaceholder"), text: $domainOrURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { searchFeeds() }

                    Button {
                        searchFeeds()
                    } label: {
                        HStack {
                            Text(String(localized: "AddFeed.Search"))
                            if isSearching {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(domainOrURL.isEmpty || isSearching)
                } header: {
                    Text(String(localized: "AddFeed.Section.Search"))
                } footer: {
                    Text(String(localized: "AddFeed.Section.SearchFooter"))
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
                                        .foregroundStyle(.green)
                                } else {
                                    Button {
                                        addFeed(feed)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    } header: {
                        Text(String(localized: "AddFeed.Section.Discovered"))
                    }
                }

                Section {
                    TextField(String(localized: "AddFeed.DirectURL"), text: $domainOrURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button(String(localized: "AddFeed.AddDirectly")) {
                        addDirectURL()
                    }
                    .disabled(domainOrURL.isEmpty)
                } header: {
                    Text(String(localized: "AddFeed.Section.Direct"))
                } footer: {
                    Text(String(localized: "AddFeed.Section.DirectFooter"))
                }
            }
            .navigationTitle(String(localized: "AddFeed.Title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Shared.Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func searchFeeds() {
        isSearching = true
        errorMessage = nil
        discoveredFeeds = []

        let domain = extractDomain(from: domainOrURL)

        Task {
            let feeds = await FeedDiscovery.shared.discoverFeeds(forDomain: domain)
            isSearching = false
            if feeds.isEmpty {
                errorMessage = String(localized: "AddFeed.NoFeedsFound")
            } else {
                discoveredFeeds = feeds
            }
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addDirectURL() {
        var urlString = domainOrURL
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        Task {
            isSearching = true
            defer { isSearching = false }

            guard let url = URL(string: urlString) else {
                errorMessage = String(localized: "AddFeed.InvalidURL")
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let parser = RSSParser()
                if let parsed = parser.parse(data: data) {
                    let siteURL = parsed.siteURL.isEmpty ? urlString : parsed.siteURL
                    let title = parsed.title.isEmpty
                        ? (url.host ?? urlString) : parsed.title
                    try feedManager.addFeed(
                        url: urlString,
                        title: title,
                        siteURL: siteURL,
                        description: parsed.description
                    )
                    dismiss()
                } else {
                    errorMessage = String(localized: "AddFeed.NotAFeed")
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
