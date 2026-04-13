import SwiftUI

extension OnboardingView {

    var addFeedStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "plus.circle.fill",
                    title: String(localized: "Onboarding.AddFirstFeed.Title"),
                    description: String(localized: "Onboarding.AddFirstFeed.Prompt")
                )

                VStack(spacing: 0) {
                    TextField("AddFeed.URLPlaceholder", text: $urlInput)
                        .focused($isURLFieldFocused)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { searchFeeds() }
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                    Divider()
                        .padding(.leading)

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
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .disabled(urlInput.isEmpty || isSearching)
                }
                .background(.regularMaterial, in: .rect(cornerRadius: 20))

                if urlInput.isEmpty {
                    RSSDiscoveryInlineSection()
                }

                if let errorMessage = feedErrorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }

                if !discoveredFeeds.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AddFeed.Section.Discovered")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            ForEach(Array(discoveredFeeds.enumerated()), id: \.element.id) { index, feed in
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

                                    if isFeedAlreadyAdded(feed.url) {
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
                                .padding(.horizontal)
                                .padding(.vertical, 12)

                                if index < discoveredFeeds.count - 1 {
                                    Divider()
                                        .padding(.leading)
                                }
                            }
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .animation(.smooth.speed(2.0), value: urlInput.isEmpty)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !feedManager.feeds.isEmpty {
                    Button {
                        onComplete()
                    } label: {
                        Text("Onboarding.GetStarted")
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                } else {
                    Button {
                        onComplete()
                    } label: {
                        Text("Onboarding.SkipForNow")
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .padding(.bottom, isIPad ? 20 : 0)
        }
        .onAppear {
            isURLFieldFocused = true
        }
    }

    // MARK: - Feed Search

    func searchFeeds() {
        isSearching = true
        feedErrorMessage = nil
        discoveredFeeds = []

        Task {
            var results: [DiscoveredFeed] = []

            if let feed = await tryDirectFeedURL(urlInput) {
                results.append(feed)
            }

            let normalizedURL = normalizeURL(urlInput)
            if let url = URL(string: normalizedURL) {
                let urlFeeds = await FeedDiscovery.shared.discoverFeeds(fromPageURL: url)
                results.append(contentsOf: urlFeeds)
            }

            if results.isEmpty {
                let domain = extractDomain(from: urlInput)
                let domainFeeds = await FeedDiscovery.shared.discoverFeeds(forDomain: domain)
                results.append(contentsOf: domainFeeds)
            }

            var seen = Set<String>()
            results = results.filter { seen.insert($0.url).inserted }
            results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            await MainActor.run {
                withAnimation(.smooth.speed(2.0)) {
                    isSearching = false
                    if results.isEmpty {
                        feedErrorMessage = String(localized: "AddFeed.NoFeedsFound")
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
            let (data, response) = try await URLSession.shared.data(for: .sakura(url: fetchURL))
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

    func isFeedAlreadyAdded(_ url: String) -> Bool {
        addedURLs.contains(url) || feedManager.feeds.contains(where: { $0.url == url })
    }

    func addFeed(_ discovered: DiscoveredFeed) {
        do {
            try feedManager.addFeed(
                url: discovered.url,
                title: discovered.title,
                siteURL: discovered.siteURL
            )
            addedURLs.insert(discovered.url)
        } catch {
            feedErrorMessage = error.localizedDescription
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
