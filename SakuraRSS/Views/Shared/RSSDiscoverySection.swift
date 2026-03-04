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
            Text("AddFeed.Discovery.Header")
        } footer: {
            Text("AddFeed.Discovery.Footer.\(appName)")
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
            Text("AddFeed.Discovery.Header")
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

            Text("AddFeed.Discovery.Footer.\(appName)")
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
