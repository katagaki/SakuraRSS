import UIKit
import UniformTypeIdentifiers

class ActionViewController: UIViewController {

    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private let feedsStackView = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private var discoveredFeeds: [DiscoveredFeed] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractURLAndDiscover()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        let navItem = UINavigationItem(title: NSLocalizedString("AddFeed.Title", comment: ""))
        navItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(done)
        )
        navBar.items = [navItem]

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = NSLocalizedString("AddFeed.Extension.Searching", comment: "")
        stackView.addArrangedSubview(statusLabel)

        activityIndicator.startAnimating()
        stackView.addArrangedSubview(activityIndicator)

        feedsStackView.axis = .vertical
        feedsStackView.spacing = 8
        feedsStackView.alignment = .fill
        stackView.addArrangedSubview(feedsStackView)
    }

    private func extractURLAndDiscover() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showError(NSLocalizedString("AddFeed.Extension.NoURL", comment: ""))
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                        guard let url = item as? URL else {
                            Task { @MainActor in
                                self?.showError(NSLocalizedString("AddFeed.Extension.NoURL", comment: ""))
                            }
                            return
                        }
                        Task { @MainActor in
                            await self?.discoverFeeds(from: url)
                        }
                    }
                    return
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                        guard let text = item as? String, let url = URL(string: text) else {
                            Task { @MainActor in
                                self?.showError(NSLocalizedString("AddFeed.Extension.NoURL", comment: ""))
                            }
                            return
                        }
                        Task { @MainActor in
                            await self?.discoverFeeds(from: url)
                        }
                    }
                    return
                }
            }
        }

        showError(NSLocalizedString("AddFeed.Extension.NoURL", comment: ""))
    }

    private func discoverFeeds(from url: URL) async {
        guard let host = url.host else {
            showError(NSLocalizedString("AddFeed.Extension.NoURL", comment: ""))
            return
        }

        statusLabel.text = String(format: NSLocalizedString("AddFeed.Extension.SearchingDomain", comment: ""), host)

        let feeds = await FeedDiscovery.shared.discoverFeeds(forDomain: host)

        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true

        if feeds.isEmpty {
            statusLabel.text = NSLocalizedString("AddFeed.NoFeedsFound", comment: "")
        } else {
            discoveredFeeds = feeds
            statusLabel.text = String(
                format: NSLocalizedString("AddFeed.Extension.FoundFeeds", comment: ""),
                feeds.count
            )
            showDiscoveredFeeds()
        }
    }

    private func showDiscoveredFeeds() {
        for (index, feed) in discoveredFeeds.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index

            var config = UIButton.Configuration.filled()
            config.title = feed.title
            config.subtitle = feed.url
            config.titleAlignment = .leading
            config.cornerStyle = .medium
            button.configuration = config

            button.addTarget(self, action: #selector(addFeedTapped(_:)), for: .touchUpInside)
            feedsStackView.addArrangedSubview(button)

            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalTo: feedsStackView.widthAnchor).isActive = true
        }
    }

    @objc private func addFeedTapped(_ sender: UIButton) {
        let feed = discoveredFeeds[sender.tag]

        do {
            try DatabaseManager.shared.insertFeed(
                title: feed.title,
                url: feed.url,
                siteURL: feed.siteURL
            )

            sender.configuration?.title = NSLocalizedString("AddFeed.Extension.Added", comment: "")
            sender.configuration?.baseBackgroundColor = .systemGreen
            sender.isEnabled = false
        } catch {
            sender.configuration?.title = NSLocalizedString("AddFeed.Extension.AlreadyAdded", comment: "")
            sender.isEnabled = false
        }
    }

    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusLabel.text = message
    }

    @objc func done() {
        extensionContext?.completeRequest(returningItems: extensionContext?.inputItems, completionHandler: nil)
    }
}
