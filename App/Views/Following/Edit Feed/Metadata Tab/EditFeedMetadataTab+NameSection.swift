import SwiftUI

extension EditFeedMetadataTab {

    @ViewBuilder
    func nameSection(for feed: Feed) -> some View {
        Section {
            TextField(String(localized: "FeedEdit.Name", table: "Feeds"), text: $name)
                .frame(maxWidth: .infinity)
                .labelsHidden()
                .onSubmit { commitNameAndIcon() }
        } header: {
            Text(String(localized: "FeedEdit.Name", table: "Feeds"))
        }
    }

    @ViewBuilder
    func urlSection(for feed: Feed) -> some View {
        if feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed {
            Section {
                Text(feed.siteURL)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } header: {
                Text(String(localized: "FeedEdit.URL", table: "Feeds"))
            }
        } else if !PetalRecipe.isPetalFeedURL(feed.url) {
            Section {
                TextField(String(localized: "FeedEdit.URL", table: "Feeds"), text: $url)
                    .frame(maxWidth: .infinity)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .labelsHidden()
                    .onSubmit { commitNameAndIcon() }
            } header: {
                Text(String(localized: "FeedEdit.URL", table: "Feeds"))
            }
        }
    }
}
