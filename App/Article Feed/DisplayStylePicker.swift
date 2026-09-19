import SwiftUI
import Hanami

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
                styleLabel(.inbox)
                styleLabel(.compact)
                if showTimeline {
                    styleLabel(.timeline)
                }
            }
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
            Picker(String(localized: "StyleSection.MediaFocused", table: "Articles"), selection: $displayStyle) {
                styleLabel(.feed)
                styleLabel(.feedCompact)
                if hasImages {
                    styleLabel(.photos)
                }
                if showVideo {
                    styleLabel(.video)
                }
                if showPodcast {
                    styleLabel(.podcast)
                }
            }
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
            Picker(String(localized: "StyleSection.Grids", table: "Articles"), selection: $displayStyle) {
                if hasImages {
                    styleLabel(.magazine)
                }
                if hasImages {
                    styleLabel(.masonry)
                }
                if hasImages {
                    styleLabel(.grid)
                }
            }
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
            if (hasImages && showCards) || showScroll {
                Picker(String(localized: "StyleSection.Immersive", table: "Articles"), selection: $displayStyle) {
                    if hasImages && showCards {
                        styleLabel(.cards)
                    }
                    if showScroll {
                        styleLabel(.scroll)
                    }
                }
                .pickerStyle(.inline)
                .labelsVisibility(.visible)
            }
        }
        .menuActionDismissBehavior(.disabled)
    }

    private func styleLabel(_ style: FeedDisplayStyle) -> some View {
        Label(style.localizedName, systemImage: style.symbol)
            .tag(style)
    }
}
