import SwiftUI

struct ScrollEndOfFeedPage: View {

    let pageSize: CGSize
    let onLoadMore: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            ContentUnavailableView {
                Label(
                    String(
                        localized: "Scroll.EndOfFeed.Title",
                        table: "Articles"
                    ),
                    systemImage: "clock.arrow.circlepath"
                )
                .foregroundStyle(.white)
            } description: {
                Text(
                    String(
                        localized: "Scroll.EndOfFeed.Description",
                        table: "Articles"
                    )
                )
                .foregroundStyle(.white.opacity(0.75))
            } actions: {
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
        }
        .frame(width: pageSize.width, height: pageSize.height)
    }
}
