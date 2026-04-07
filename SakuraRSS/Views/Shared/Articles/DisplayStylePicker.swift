import SwiftUI

struct DisplayStylePicker: View {

    @Binding var displayStyle: FeedDisplayStyle
    let hasImages: Bool
    var showTimeline: Bool = true
    var showVideo: Bool = false
    var showPodcast: Bool = false
    var showCards: Bool = true

    var body: some View {
        Section(String(localized: "Articles.StyleSection.Classic")) {
            Picker(selection: $displayStyle) {
                Label(String(localized: "Articles.Style.Inbox"), systemImage: "tray")
                    .tag(FeedDisplayStyle.inbox)
                if hasImages {
                    Label(String(localized: "Articles.Style.Magazine"), systemImage: "rectangle.grid.2x2")
                        .tag(FeedDisplayStyle.magazine)
                }
                Label(String(localized: "Articles.Style.Compact"), systemImage: "list.dash")
                    .tag(FeedDisplayStyle.compact)
            } label: {
                EmptyView()
            }
            .menuActionDismissBehavior(.disabled)
        }
        Section(String(localized: "Articles.StyleSection.Visual")) {
            Picker(selection: $displayStyle) {
                Label(String(localized: "Articles.Style.Feed"), systemImage: "newspaper")
                    .tag(FeedDisplayStyle.feed)
                if hasImages {
                    Label(String(localized: "Articles.Style.Photos"), systemImage: "photo.stack")
                        .tag(FeedDisplayStyle.photos)
                }
                if hasImages {
                    Label(String(localized: "Articles.Style.Grid"), systemImage: "square.grid.3x3")
                        .tag(FeedDisplayStyle.grid)
                }
            } label: {
                EmptyView()
            }
            .menuActionDismissBehavior(.disabled)
        }
        Section(String(localized: "Articles.StyleSection.Specialized")) {
            Picker(selection: $displayStyle) {
                if hasImages && showCards {
                    Label(String(localized: "Articles.Style.Cards"), systemImage: "square.stack.3d.up")
                        .tag(FeedDisplayStyle.cards)
                }
                if showTimeline {
                    Label(String(localized: "Articles.Style.Timeline"), systemImage: "clock")
                        .tag(FeedDisplayStyle.timeline)
                }
                if showVideo {
                    Label(String(localized: "Articles.Style.Video"), systemImage: "play.rectangle")
                        .tag(FeedDisplayStyle.video)
                }
                if showPodcast {
                    Label(String(localized: "Articles.Style.Podcast"), systemImage: "headphones")
                        .tag(FeedDisplayStyle.podcast)
                }
            } label: {
                EmptyView()
            }
            .menuActionDismissBehavior(.disabled)
        }
    }
}
