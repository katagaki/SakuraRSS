import SwiftUI

struct UnreadDotView: View {

    let isRead: Bool

    var body: some View {
        Circle()
            .fill(isRead ? .clear : .blue)
            .frame(width: 8, height: 8)
    }
}
