import SwiftUI

struct DisplayStylePicker: View {

    @Binding var displayStyle: FeedDisplayStyle
    let hasImages: Bool
    var showTimeline: Bool = true
    var showVideo: Bool = true
    var showPodcast: Bool = false
    var showCards: Bool = true
    var showScroll: Bool = true

    var body: some View {
        Group {
            Picker(String(localized: "StyleSection.Classic", table: "Articles"), selection: $displayStyle) {
                Label(String(localized: "Style.Inbox", table: "Articles"), systemImage: "tray")
                    .tag(FeedDisplayStyle.inbox)
                Label(String(localized: "Style.Compact", table: "Articles"), systemImage: "list.dash")
                    .tag(FeedDisplayStyle.compact)
                if showTimeline {
                    Label(String(localized: "Style.Timeline", table: "Articles"), systemImage: "clock")
                        .tag(FeedDisplayStyle.timeline)
                }
            }
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
            Picker(String(localized: "StyleSection.MediaFocused", table: "Articles"), selection: $displayStyle) {
                Label(String(localized: "Style.Feed", table: "Articles"), systemImage: "text.rectangle.page")
                    .tag(FeedDisplayStyle.feed)
                Label(String(localized: "Style.FeedCompact", table: "Articles"), systemImage: "square.text.square")
                    .tag(FeedDisplayStyle.feedCompact)
                if hasImages {
                    Label(String(localized: "Style.Photos", table: "Articles"), systemImage: "photo.stack")
                        .tag(FeedDisplayStyle.photos)
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
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
            Picker(String(localized: "StyleSection.Grids", table: "Articles"), selection: $displayStyle) {
                if hasImages {
                    Label(String(localized: "Style.Magazine", table: "Articles"), systemImage: "rectangle.grid.2x2")
                        .tag(FeedDisplayStyle.magazine)
                }
                if hasImages {
                    Label(String(localized: "Style.Masonry", table: "Articles"), systemImage: "rectangle.3.group")
                        .tag(FeedDisplayStyle.masonry)
                }
                if hasImages {
                    Label(String(localized: "Style.Grid", table: "Articles"), systemImage: "square.grid.3x3")
                        .tag(FeedDisplayStyle.grid)
                }
            }
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
            Picker(String(localized: "StyleSection.Immersive", table: "Articles"), selection: $displayStyle) {
                if hasImages && showCards {
                    Label(String(localized: "Style.Cards", table: "Articles"), systemImage: "square.stack.3d.up")
                        .tag(FeedDisplayStyle.cards)
                }
                if showScroll {
                    Label(String(localized: "Style.Scroll", table: "Articles"), systemImage: "arrow.up.and.down")
                        .tag(FeedDisplayStyle.scroll)
                }
            }
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
        }
        .menuActionDismissBehavior(.disabled)
    }
}
