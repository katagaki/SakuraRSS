import SwiftUI
import Hanami

/// Root view of the toast overlay window.
struct BookmarkToastOverlayView: View {

    let feedManager: FeedManager
    private let toastManager = BookmarkToastManager.shared

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            if let article = toastManager.article {
                BookmarkToastView(article: article)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(feedManager)
    }

    private var bottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 72.0 : 24.0
    }
}
