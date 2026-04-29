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
            Picker(String(localized: "StyleSection.Classic", table: "Articles"), selection: $displayStyle) {
                Label(String(localized: "Style.Inbox", table: "Articles"), systemImage: "tray")
                    .tag(FeedDisplayStyle.inbox)
                if hasImages {
                    Label(String(localized: "Style.Magazine", table: "Articles"), systemImage: "rectangle.grid.2x2")
                        .tag(FeedDisplayStyle.magazine)
                }
                Label(String(localized: "Style.Compact", table: "Articles"), systemImage: "list.dash")
                    .tag(FeedDisplayStyle.compact)
            }
            Picker(String(localized: "StyleSection.Visual", table: "Articles"), selection: $displayStyle) {
                Label(String(localized: "Style.Feed", table: "Articles"), systemImage: "text.rectangle.page")
                    .tag(FeedDisplayStyle.feed)
                Label(String(localized: "Style.FeedCompact", table: "Articles"), systemImage: "square.text.square")
                    .tag(FeedDisplayStyle.feedCompact)
                if hasImages {
                    Label(String(localized: "Style.Photos", table: "Articles"), systemImage: "photo.stack")
                        .tag(FeedDisplayStyle.photos)
                }
                if hasImages {
                    Label(String(localized: "Style.Grid", table: "Articles"), systemImage: "square.grid.3x3")
                        .tag(FeedDisplayStyle.grid)
                }
            }
            Picker(String(localized: "StyleSection.Specialized", table: "Articles"), selection: $displayStyle) {
                if hasImages && showCards {
                    Label(String(localized: "Style.Cards", table: "Articles"), systemImage: "square.stack.3d.up")
                        .tag(FeedDisplayStyle.cards)
                }
                if showScroll {
                    Label(String(localized: "Style.Scroll", table: "Articles"), systemImage: "arrow.up.and.down")
                        .tag(FeedDisplayStyle.scroll)
                }
                if showTimeline {
                    Label(String(localized: "Style.Timeline", table: "Articles"), systemImage: "clock")
                        .tag(FeedDisplayStyle.timeline)
                }
                if showVideo {
                    Label(String(localized: "Style.Video", table: "Articles"), systemImage: "play.rectangle")
                        .tag(FeedDisplayStyle.video)
                }
                if showPodcast {
                    Label(String(localized: "Style.Podcast", table: "Articles"), systemImage: "headphones")
                        .tag(FeedDisplayStyle.podcast)
                }
            }
        }
        .pickerStyle(.inline)
        .menuActionDismissBehavior(.disabled)
    }
}
