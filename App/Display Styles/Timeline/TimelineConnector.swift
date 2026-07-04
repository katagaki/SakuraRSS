import SwiftUI
import Hanami

struct TimelineConnector: View {

    let isFirst: Bool
    let isLast: Bool
    let isRead: Bool

    private static let dotSize: CGFloat = 10
    private static let dotCenterY: CGFloat = 19

    var body: some View {
        VStack(spacing: 0) {
            connectorLine(isVisible: !isFirst)
                .frame(height: Self.dotCenterY - Self.dotSize / 2)
            Circle()
                .fill(isRead ? Color.blue.opacity(0.3) : Color.blue)
                .frame(width: Self.dotSize, height: Self.dotSize)
            connectorLine(isVisible: !isLast)
                .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func connectorLine(isVisible: Bool) -> some View {
        if isVisible {
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 2)
        } else {
            Color.clear
                .frame(width: 2)
        }
    }
}
