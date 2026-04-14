import SwiftUI

struct DisplayStylePicker: View {

    @Binding var displayStyle: FeedDisplayStyle
    let hasImages: Bool
    var showTimeline: Bool = true
    var showVideo: Bool = false
    var showPodcast: Bool = false
    var showCards: Bool = true
    var showScroll: Bool = true

    var body: some View {
        Group {
            Picker("Articles.StyleSection.Classic", selection: $displayStyle) {
                Label("Articles.Style.Inbox", systemImage: "tray")
                    .tag(FeedDisplayStyle.inbox)
                if hasImages {
                    Label("Articles.Style.Magazine", systemImage: "rectangle.grid.2x2")
                        .tag(FeedDisplayStyle.magazine)
                }
                Label("Articles.Style.Compact", systemImage: "list.dash")
                    .tag(FeedDisplayStyle.compact)
            }
            Picker("Articles.StyleSection.Visual", selection: $displayStyle) {
                Label("Articles.Style.Feed", systemImage: "text.rectangle.page")
                    .tag(FeedDisplayStyle.feed)
                Label("Articles.Style.FeedCompact", systemImage: "square.text.square")
                    .tag(FeedDisplayStyle.feedCompact)
                if hasImages {
                    Label("Articles.Style.Photos", systemImage: "photo.stack")
                        .tag(FeedDisplayStyle.photos)
                }
                if hasImages {
                    Label("Articles.Style.Grid", systemImage: "square.grid.3x3")
                        .tag(FeedDisplayStyle.grid)
                }
            }
            Picker("Articles.StyleSection.Specialized", selection: $displayStyle) {
                if hasImages && showCards {
                    Label("Articles.Style.Cards", systemImage: "square.stack.3d.up")
                        .tag(FeedDisplayStyle.cards)
                }
                if showScroll {
                    Label("Articles.Style.Scroll", systemImage: "arrow.up.and.down")
                        .tag(FeedDisplayStyle.scroll)
                }
                if showTimeline {
                    Label("Articles.Style.Timeline", systemImage: "clock")
                        .tag(FeedDisplayStyle.timeline)
                }
                if showVideo {
                    Label("Articles.Style.Video", systemImage: "play.rectangle")
                        .tag(FeedDisplayStyle.video)
                }
                if showPodcast {
                    Label("Articles.Style.Podcast", systemImage: "headphones")
                        .tag(FeedDisplayStyle.podcast)
                }
            }
        }
        .pickerStyle(.inline)
        .menuActionDismissBehavior(.disabled)
    }
}
