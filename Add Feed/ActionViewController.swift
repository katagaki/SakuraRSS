import SwiftUI
import UniformTypeIdentifiers
import Hanami

class ActionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(
            rootView: ActionExtensionView(extensionContext: extensionContext)
        )
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

@Observable
class ActionExtensionModel {
    var status: Status = .searching
    var discoveredFeeds: [DiscoveredFeed] = []
    var addedFeedIDs: Set<UUID> = []
    var duplicateFeedIDs: Set<UUID> = []
    var sharedPageURL: URL?

    enum Status {
        case searching
        case searchingDomain(String)
        case found(Int)
        case noFeeds
        case noURL
    }
}

struct ActionExtensionView: View {

    weak var extensionContext: NSExtensionContext?
    @State private var model = ActionExtensionModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "AddFeed.Title", table: "Feeds"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) {
                            extensionContext?.completeRequest(
                                returningItems: extensionContext?.inputItems,
                                completionHandler: nil
                            )
                        }
                    }
                }
        }
        .task {
            await extractURLAndDiscover()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.status {
        case .searching:
            ContentUnavailableView {
                ProgressView()
            } description: {
                Text(String(localized: "AddFeed.Extension.Searching", table: "Feeds"))
            }
        case .searchingDomain(let domain):
            ContentUnavailableView {
                ProgressView()
            } description: {
                Text(String(localized: "AddFeed.Extension.SearchingDomain \(domain)", table: "Feeds"))
            }
        case .found:
            List {
                Section {
                    ForEach(model.discoveredFeeds) { feed in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.title)
                                    .lineLimit(1)
                                Text(feed.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if requiresAppToAdd(feed.url) {
                                    Text(String(localized: "AddFeed.Extension.RequiresApp", table: "Feeds"))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            if model.addedFeedIDs.contains(feed.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            } else if model.duplicateFeedIDs.contains(feed.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            } else if requiresAppToAdd(feed.url) {
                                Button {
                                    openAppToAdd(feed)
                                } label: {
                                    Image(systemName: "arrow.up.forward.app.fill")
                                        .font(.title2)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(String(localized: "AddFeed.Extension.OpenApp", table: "Feeds"))
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
                    Text(String(localized: "AddFeed.Section.Discovered", table: "Feeds"))
                }
            }
        case .noFeeds:
            ContentUnavailableView(
                String(localized: "AddFeed.NoFeedsFound", table: "Feeds"),
                systemImage: "rectangle.on.rectangle.slash"
            )
        case .noURL:
            ContentUnavailableView(
                String(localized: "AddFeed.Extension.NoURL", table: "Feeds"),
                systemImage: "link.badge.plus"
            )
        }
    }

    private func extractURLAndDiscover() async {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            model.status = .noURL
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                   let url = item as? URL {
                    await discoverFeeds(from: url)
                    return
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                   let text = item as? String,
                   let url = URL(string: text) {
                    await discoverFeeds(from: url)
                    return
                }
            }
        }

        model.status = .noURL
    }

    private func discoverFeeds(from url: URL) async {
        model.sharedPageURL = url
        guard let host = url.host else {
            model.status = .noURL
            return
        }

        model.status = .searchingDomain(host)

        let pageFeeds = await FeedDiscovery.shared.discoverFeeds(fromPageURL: url)
        if !pageFeeds.isEmpty {
            model.discoveredFeeds = pageFeeds
            model.status = .found(pageFeeds.count)
            return
        }

        let feeds = await FeedDiscovery.shared.discoverFeeds(forDomain: host)

        if feeds.isEmpty {
            model.status = .noFeeds
        } else {
            model.discoveredFeeds = feeds
            model.status = .found(feeds.count)
        }
    }

    private func addFeed(_ feed: DiscoveredFeed) {
        do {
            try DatabaseManager.shared.insertFeed(
                title: feed.title,
                url: feed.url,
                siteURL: feed.siteURL
            )
            model.addedFeedIDs.insert(feed.id)
        } catch {
            model.duplicateFeedIDs.insert(feed.id)
        }
    }

    /// X and Instagram feeds need an in-app login session, so they can't be
    /// added from the extension; the user is sent to the app to sign in.
    private func requiresAppToAdd(_ url: String) -> Bool {
        XProvider.isFeedURL(url) || InstagramProvider.isFeedURL(url)
    }

    private func openAppToAdd(_ feed: DiscoveredFeed) {
        var components = URLComponents()
        components.scheme = "sakura"
        components.host = "addfeed"
        components.queryItems = [
            URLQueryItem(name: "url", value: model.sharedPageURL?.absoluteString ?? feed.url)
        ]
        guard let appURL = components.url else { return }
        extensionContext?.open(appURL)
    }
}
