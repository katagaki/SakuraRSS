import SwiftUI

extension AllArticlesView {

    @ViewBuilder
    var titleMenuContent: some View {
        ForEach(followingSections) { section in
            sectionButton(for: section)
        }

        if !primarySections.isEmpty || !socialSections.isEmpty || !videoSections.isEmpty {
            Divider()
        }

        ForEach(primarySections) { section in
            sectionButton(for: section)
        }

        if !socialSections.isEmpty {
            Menu {
                ForEach(socialSections) { section in
                    sectionButton(for: section)
                }
            } label: {
                Label(
                    String(localized: "FeedSection.Social", table: "Feeds"),
                    systemImage: "person.2"
                )
            }
        }

        if !videoSections.isEmpty {
            Menu {
                ForEach(videoSections) { section in
                    sectionButton(for: section)
                }
            } label: {
                Label(
                    String(localized: "FeedSection.Video", table: "Feeds"),
                    systemImage: "play.rectangle"
                )
            }
        }

        if !feedManager.lists.isEmpty {
            Divider()
            ForEach(feedManager.lists) { list in
                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        selectedSelection = .list(list.id)
                    }
                } label: {
                    Label(list.name, systemImage: list.icon)
                }
            }
        }
    }
}
