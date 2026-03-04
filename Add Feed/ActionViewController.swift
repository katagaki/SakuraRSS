import SwiftUI
import UniformTypeIdentifiers

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
                .navigationTitle(String(localized: "AddFeed.Title"))
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
                Text("AddFeed.Extension.Searching")
            }
        case .searchingDomain(let domain):
            ContentUnavailableView {
                ProgressView()
            } description: {
                Text("AddFeed.Extension.SearchingDomain \(domain)")
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
        case .noFeeds:
            ContentUnavailableView(
                String(localized: "AddFeed.NoFeedsFound"),
                systemImage: "rectangle.on.rectangle.slash"
            )
        case .noURL:
            ContentUnavailableView(
                String(localized: "AddFeed.Extension.NoURL"),
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
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                       let url = item as? URL {
                        await discoverFeeds(from: url)
                        return
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                       let text = item as? String,
                       let url = URL(string: text) {
                        await discoverFeeds(from: url)
                        return
                    }
                }
            }
        }

        model.status = .noURL
    }

    private func discoverFeeds(from url: URL) async {
        guard let host = url.host else {
            model.status = .noURL
            return
        }

        model.status = .searchingDomain(host)

        // Try page URL discovery first (handles social media profiles and page-level feeds)
        let pageFeeds = await FeedDiscovery.shared.discoverFeeds(fromPageURL: url)
        if !pageFeeds.isEmpty {
            model.discoveredFeeds = pageFeeds
            model.status = .found(pageFeeds.count)
            return
        }

        // Fall back to domain-level discovery
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
}
