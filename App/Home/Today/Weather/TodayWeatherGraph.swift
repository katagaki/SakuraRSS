import SwiftUI

struct TodayWeatherGraph: View {

    let values: [Double]
    let lowerBound: Double
    let upperBound: Double
    let color: Color
    var horizontalInset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let points = points(in: proxy.size)
            if points.count > 1 {
                area(points, height: proxy.size.height)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.05), color.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let count = values.count
        guard count > 1 else { return [] }
        let span = max(upperBound - lowerBound, 1)
        let usableWidth = max(size.width - horizontalInset * 2, 1)
        return values.enumerated().map { index, value in
            let positionX = horizontalInset + usableWidth * CGFloat(index) / CGFloat(count - 1)
            let normalized = min(max((value - lowerBound) / span, 0), 1)
            let positionY = size.height - CGFloat(normalized) * size.height
            return CGPoint(x: positionX, y: positionY)
        }
    }

    private func area(_ points: [CGPoint], height: CGFloat) -> Path {
        guard let first = points.first, let last = points.last else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: first.x, y: height))
        path.addLine(to: first)
        for index in 0..<(points.count - 1) {
            let previous = points[max(index - 1, 0)]
            let start = points[index]
            let end = points[index + 1]
            let next = points[min(index + 2, points.count - 1)]
            let control1 = CGPoint(
                x: start.x + (end.x - previous.x) / 6,
                y: start.y + (end.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: end.x - (next.x - start.x) / 6,
                y: end.y - (next.y - start.y) / 6
            )
            path.addCurve(to: end, control1: control1, control2: control2)
        }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.closeSubpath()
        return path
    }
}
