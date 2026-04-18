import SwiftUI

struct TimelineConnector: View {

    let isFirst: Bool
    let isLast: Bool
    let isRead: Bool

    var body: some View {
        GeometryReader { geometry in
            let midX = geometry.size.width / 2
            let dotSize: CGFloat = 10
            let dotY: CGFloat = 19

            if !isFirst {
                Path { path in
                    path.move(to: CGPoint(x: midX, y: 0))
                    path.addLine(to: CGPoint(x: midX, y: dotY - dotSize / 2))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
            }

            if !isLast {
                Path { path in
                    path.move(to: CGPoint(x: midX, y: dotY + dotSize / 2))
                    path.addLine(to: CGPoint(x: midX, y: geometry.size.height))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
            }

            Circle()
                .fill(isRead ? Color.blue.opacity(0.3) : Color.blue)
                .frame(width: dotSize, height: dotSize)
                .position(x: midX, y: dotY)
        }
    }
}
