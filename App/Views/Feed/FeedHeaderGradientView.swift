import SwiftUI

struct FeedHeaderGradientView: View {

    let colors: [Color]

    private static let meshPoints: [SIMD2<Float>] = [
        [0.0, 0.0], [0.55, 0.0], [1.0, 0.0],
        [0.0, 0.45], [0.65, 0.55], [1.0, 0.4],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
    ]

    var body: some View {
        let palette = paddedPalette(colors)

        MeshGradient(
            width: 3,
            height: 3,
            points: Self.meshPoints,
            colors: [
                palette[0], palette[1], palette[2],
                palette[3], palette[0], palette[1],
                palette[2], palette[3], palette[0]
            ]
        )
        .opacity(0.28)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black.opacity(0.55), location: 0.55),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    private func paddedPalette(_ colors: [Color]) -> [Color] {
        guard !colors.isEmpty else {
            return Array(repeating: Color.gray, count: 4)
        }
        if colors.count >= 4 { return Array(colors.prefix(4)) }
        var padded = colors
        while padded.count < 4 {
            padded.append(colors[padded.count % colors.count])
        }
        return padded
    }
}
