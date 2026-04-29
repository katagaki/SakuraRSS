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
            Text(String(localized: "Refresh.NewContent", table: "Articles"))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
}
