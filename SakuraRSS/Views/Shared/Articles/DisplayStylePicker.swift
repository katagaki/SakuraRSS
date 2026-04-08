import SwiftUI

struct DisplayStylePicker: View {

    @Binding var displayStyle: FeedDisplayStyle
    let hasImages: Bool
    var showTimeline: Bool = true
    var showVideo: Bool = false
    var showPodcast: Bool = false
    var showCards: Bool = true

    var body: some View {
        Section("Articles.StyleSection.Classic") {
            Picker(selection: $displayStyle) {
                Label("Articles.Style.Inbox"), systemImage: "tray")
                    .tag(FeedDisplayStyle.inbox)
                if hasImages {
                    Label("Articles.Style.Magazine"), systemImage: "rectangle.grid.2x2")
                        .tag(FeedDisplayStyle.magazine)
                }
                Label("Articles.Style.Compact"), systemImage: "list.dash")
                    .tag(FeedDisplayStyle.compact)
            } label: {
                EmptyView()
            }
            .menuActionDismissBehavior(.disabled)
        }
        Section("Articles.StyleSection.Visual") {
            Picker(selection: $displayStyle) {
                Label("Articles.Style.Feed"), systemImage: "newspaper")
                    .tag(FeedDisplayStyle.feed)
                if hasImages {
                    Label("Articles.Style.Photos"), systemImage: "photo.stack")
                        .tag(FeedDisplayStyle.photos)
                }
                if hasImages {
                    Label("Articles.Style.Grid"), systemImage: "square.grid.3x3")
                        .tag(FeedDisplayStyle.grid)
                }
            } label: {
                EmptyView()
            }
            .menuActionDismissBehavior(.disabled)
        }
        Section("Articles.StyleSection.Specialized") {
            Picker(selection: $displayStyle) {
                if hasImages && showCards {
                    Label("Articles.Style.Cards"), systemImage: "square.stack.3d.up")
                        .tag(FeedDisplayStyle.cards)
                }
                if showTimeline {
                    Label("Articles.Style.Timeline"), systemImage: "clock")
                        .tag(FeedDisplayStyle.timeline)
                }
                if showVideo {
                    Label("Articles.Style.Video"), systemImage: "play.rectangle")
                        .tag(FeedDisplayStyle.video)
                }
                if showPodcast {
                    Label("Articles.Style.Podcast"), systemImage: "headphones")
                        .tag(FeedDisplayStyle.podcast)
                }
            } label: {
                EmptyView()
            }
            .menuActionDismissBehavior(.disabled)
        }
    }
}
