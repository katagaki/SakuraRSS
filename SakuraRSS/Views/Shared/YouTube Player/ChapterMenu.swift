import SwiftUI

struct ChapterMenu: View, Equatable {

    let chapters: [YouTubeChapter]
    let onSelect: (TimeInterval) -> Void

    static func == (lhs: ChapterMenu, rhs: ChapterMenu) -> Bool {
        lhs.chapters == rhs.chapters
    }

    var body: some View {
        Menu {
            ForEach(chapters) { chapter in
                Button {
                    onSelect(chapter.startTime)
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
