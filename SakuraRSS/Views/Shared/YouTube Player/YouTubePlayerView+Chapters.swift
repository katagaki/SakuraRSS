import SwiftUI

extension YouTubePlayerView {

    @ViewBuilder
    var chapterMenu: some View {
        Menu {
            ForEach(chapters) { chapter in
                Button {
                    seek(to: chapter.startTime)
                } label: {
                    Text(chapter.title)
                    Text(chapter.formattedTimestamp)
                }
            }
        } label: {
            Label(
                String(localized: "YouTube.Chapters", table: "Integrations"),
                systemImage: "list.bullet"
            )
        }
    }
}
