import SwiftUI
import Hanami

struct ScrollEndOfFeedPage: View {

    let pageSize: CGSize
    let onLoadMore: (() -> Void)?
    let onBackToTop: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            ContentUnavailableView {
                Label(
                    String(
                        localized: "Scroll.EndOfFeed.Title",
                        table: "Articles"
                    ),
                    systemImage: onLoadMore != nil ? "clock.arrow.circlepath" : "checkmark.circle"
                )
                .foregroundStyle(.white)
            } description: {
                if onLoadMore != nil {
                    Text(
                        String(
                            localized: "Scroll.EndOfFeed.Description",
                            table: "Articles"
                        )
                    )
                    .foregroundStyle(.white.opacity(0.75))
                }
            } actions: {
                if let onLoadMore {
                    Button {
                        onLoadMore()
                    } label: {
                        Label(
                            String(
                                localized: "LoadPrevious",
                                table: "Articles"
                            ),
                            systemImage: "clock.arrow.circlepath"
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.2))
                    .foregroundStyle(.white)
                }
                Button {
                    onBackToTop()
                } label: {
                    Label(
                        String(
                            localized: "Scroll.EndOfFeed.BackToTop",
                            table: "Articles"
                        ),
                        systemImage: "arrow.up"
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.capsule)
                .foregroundStyle(.white)
                .padding(.top, onLoadMore == nil ? 24 : 0)
            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
    }
}
