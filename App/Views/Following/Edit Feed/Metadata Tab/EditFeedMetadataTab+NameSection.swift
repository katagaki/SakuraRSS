import SwiftUI

extension EditFeedMetadataTab {

    @ViewBuilder
    func nameSection(for feed: Feed) -> some View {
        Section {
            HStack {
                Text(String(localized: "FeedEdit.Name", table: "Feeds"))
                TextField(String(localized: "FeedEdit.Name", table: "Feeds"), text: $name)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity)
                    .labelsHidden()
                    .onSubmit { commitNameAndIcon() }
            }
            if feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed {
                HStack {
                    Text(String(localized: "FeedEdit.URL", table: "Feeds"))
                    Spacer()
                    Text(feed.siteURL)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else if !PetalRecipe.isPetalFeedURL(feed.url) {
                HStack {
                    Text(String(localized: "FeedEdit.URL", table: "Feeds"))
                    TextField(String(localized: "FeedEdit.URL", table: "Feeds"), text: $url)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .labelsHidden()
                        .onSubmit { commitNameAndIcon() }
                }
            }
        }
    }
}
