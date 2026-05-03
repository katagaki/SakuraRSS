import SwiftUI

/// Button that appears at the top of an article list when new content has
/// arrived during a refresh. Tapping it releases the pending articles into
/// the visible list.
struct RefreshPromptButton: View {

    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label(
                String(localized: "Refresh.NewContent", table: "Articles"),
                systemImage: "arrow.clockwise"
            )
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .compatibleGlassProminentButtonStyle()
        .buttonBorderShape(.capsule)
    }
}
