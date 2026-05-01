import SwiftUI

extension EditFeedMetadataTab {

    @ViewBuilder
    func descriptionSection(for feed: Feed) -> some View {
        Section {
            TextEditor(text: $feedDescription)
                .frame(minHeight: 88)
                .onChange(of: feedDescription) {
                    commitDescription()
                }
        } header: {
            Text(String(localized: "FeedEdit.Description", table: "Feeds"))
        }
    }
}
