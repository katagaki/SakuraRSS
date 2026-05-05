import SwiftUI
import UIKit

#if !os(visionOS) && !targetEnvironment(macCatalyst)
struct ThemePreviewSection: View {

    @AppStorage("Display.SakuraBackground") private var sakuraBackgroundEnabled: Bool = true
    @AppStorage("Display.FeedBackground") private var feedBackgroundEnabled: Bool = true
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox

    private static let feedPreviewColors: [Color] = [.red, .green, .blue, .yellow]

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            DeviceMockupView(
                sakuraBackgroundEnabled: sakuraBackgroundEnabled,
                feedBackgroundEnabled: feedBackgroundEnabled,
                colors: Self.feedPreviewColors,
                style: defaultDisplayStyle
            )
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }
}

private struct DeviceMockupView: View {

    let sakuraBackgroundEnabled: Bool
    let feedBackgroundEnabled: Bool
    let colors: [Color]
    let style: FeedDisplayStyle

    private var screenAspectRatio: CGFloat {
        let bounds = UIScreen.main.bounds.size
        guard bounds.height > 0 else { return 19.5 / 9.0 }
        return bounds.height / bounds.width
    }

    private var hasRoundedScreen: Bool {
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
        return bottomInset > 0
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        let height: CGFloat = 260
        let width = height / screenAspectRatio
        let cornerRadius: CGFloat = hasRoundedScreen ? 28 : 12
        let feedColumnWidth = isPad ? width * 0.30 : width

        ZStack(alignment: .top) {
            if sakuraBackgroundEnabled {
                LinearGradient(
                    colors: [
                        Color("BackgroundGradientTop"),
                        Color("BackgroundGradientBottom")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color(uiColor: .systemBackground)
            }
            HStack(spacing: 0) {
                ZStack(alignment: .top) {
                    if feedBackgroundEnabled {
                        PreviewFeedGradient(colors: colors)
                            .frame(height: height * 0.25)
                    }
                    FeedPreviewContent(style: style, deviceWidth: feedColumnWidth)
                }
                .frame(width: feedColumnWidth)
                if isPad {
                    Rectangle()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: 0.5)
                    ArticlePreviewContent(deviceWidth: width - feedColumnWidth)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct PreviewFeedGradient: View {

    let colors: [Color]

    var body: some View {
        MeshGradient(
            width: 2,
            height: 2,
            points: [
                [0.0, 0.0], [1.0, 0.0],
                [0.0, 1.0], [1.0, 1.0]
            ],
            colors: paddedColors
        )
        .opacity(0.28)
        .mask {
            LinearGradient(
                colors: [.black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    private var paddedColors: [Color] {
        guard !colors.isEmpty else {
            return Array(repeating: .gray, count: 4)
        }
        if colors.count >= 4 { return Array(colors.prefix(4)) }
        var padded = colors
        while padded.count < 4 {
            padded.append(colors[padded.count % colors.count])
        }
        return padded
    }
}
#endif
