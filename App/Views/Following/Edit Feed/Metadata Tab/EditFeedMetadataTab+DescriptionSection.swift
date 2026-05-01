import SwiftUI

extension EditFeedMetadataTab {

    @ViewBuilder
    func descriptionSection(for feed: Feed) -> some View {
        Section {
            TextEditor(text: $feedDescription)
                .scrollContentBackground(.hidden)
                .contentMargins(.horizontal, 12, for: .scrollContent)
                .contentMargins(.vertical, 6, for: .scrollContent)
                .frame(minHeight: 88)
                .listRowInsets(EdgeInsets())
                .onChange(of: feedDescription) {
                    commitDescription()
                }
        } header: {
            Text(String(localized: "FeedEdit.Description", table: "Feeds"))
        }
    }
}
