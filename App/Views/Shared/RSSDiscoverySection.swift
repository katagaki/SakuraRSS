import SwiftUI

struct RSSDiscoverySection: View {

    private let appName: String

    init() {
        appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sakura"
    }

    var body: some View {
        Section {
            ForEach(RSSDiscoverySites.all, id: \.url) { site in
                Link(destination: URL(string: site.url)!) {
                    HStack {
                        Text(site.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(String(localized: "AddFeed.Discovery.Header", table: "Feeds"))
        } footer: {
            Text(String(localized: "AddFeed.Discovery.Footer.\(appName)", table: "Feeds"))
        }
    }
}

struct RSSDiscoveryInlineSection: View {

    private let appName: String

    init() {
        appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sakura"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "AddFeed.Discovery.Header", table: "Feeds"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(RSSDiscoverySites.all.enumerated()), id: \.element.url) { index, site in
                    Link(destination: URL(string: site.url)!) {
                        HStack {
                            Text(site.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }

                    if index < RSSDiscoverySites.all.count - 1 {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text(String(localized: "AddFeed.Discovery.Footer.\(appName)", table: "Feeds"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private enum RSSDiscoverySites {
    static let all: [(name: String, url: String)] = [
        ("Feedspot", "https://rss.feedspot.com"),
        ("Awesome RSS Feeds", "https://github.com/plenaryapp/awesome-rss-feeds"),
        ("RSS-Bridge", "https://rss-bridge.org/bridge01/")
    ]
}
