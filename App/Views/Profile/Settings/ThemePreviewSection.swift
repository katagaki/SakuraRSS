import SwiftUI
import UIKit

#if !os(visionOS) && !targetEnvironment(macCatalyst)
struct ThemePreviewSection: View {

    @AppStorage("Display.SakuraBackground") private var sakuraBackgroundEnabled: Bool = true
    @AppStorage("Display.FeedBackground") private var feedBackgroundEnabled: Bool = true
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Display.ZoomTransition") private var zoomTransitionEnabled: Bool = true

    @State private var showingArticle: Bool = false

    private static let feedPreviewColors: [Color] = [.red, .green, .blue, .yellow]

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            DeviceMockupView(
                sakuraBackgroundEnabled: sakuraBackgroundEnabled,
                feedBackgroundEnabled: feedBackgroundEnabled,
                colors: Self.feedPreviewColors,
                style: defaultDisplayStyle,
                zoomTransitionEnabled: zoomTransitionEnabled,
                showingArticle: showingArticle
            )
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .task(id: zoomTransitionEnabled) {
            showingArticle = false
            await runLoop()
        }
    }

    private var animation: Animation {
        zoomTransitionEnabled
            ? .spring(duration: 0.55, bounce: 0.18)
            : .timingCurve(0.32, 0.72, 0, 1, duration: 0.45)
    }

    private func runLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1700))
            guard !Task.isCancelled else { return }
            withAnimation(animation) {
                showingArticle.toggle()
            }
        }
    }
}

private struct DeviceMockupView: View {

    let sakuraBackgroundEnabled: Bool
    let feedBackgroundEnabled: Bool
    let colors: [Color]
    let style: FeedDisplayStyle
    let zoomTransitionEnabled: Bool
    let showingArticle: Bool

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

    private func sourceRowHeight(deviceWidth: CGFloat) -> CGFloat {
        switch style {
        case .compact: return deviceWidth * 0.055
        case .feed: return deviceWidth * 0.385
        default: return deviceWidth * 0.13
        }
    }

    private func sourceRowTopY(deviceWidth: CGFloat) -> CGFloat {
        let headerSection = deviceWidth * 0.515
        let rowSpacing = deviceWidth * 0.03
        return headerSection + sourceRowHeight(deviceWidth: deviceWidth) + rowSpacing
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
                    ArticlePreviewContent(
                        deviceWidth: width - feedColumnWidth,
                        topSafeArea: hasRoundedScreen ? cornerRadius : 0
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            if !isPad {
                let rowH = sourceRowHeight(deviceWidth: width)
                let rowY = sourceRowTopY(deviceWidth: width)
                ZStack {
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
                    ArticlePreviewContent(
                        deviceWidth: width,
                        topSafeArea: hasRoundedScreen ? cornerRadius : 0
                    )
                }
                .frame(width: width, height: height)
                .scaleEffect(
                    x: phoneArticleScaleX,
                    y: phoneArticleScaleY(rowHeight: rowH, height: height),
                    anchor: phoneArticleAnchor(rowY: rowY, rowHeight: rowH, height: height)
                )
                .offset(x: phoneArticleOffsetX(width: width))
                .opacity(phoneArticleOpacity)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
        }
    }

    private var phoneArticleScaleX: CGFloat {
        guard zoomTransitionEnabled else { return 1 }
        if showingArticle { return 1 }
        return 0.9
    }

    private func phoneArticleScaleY(rowHeight: CGFloat, height: CGFloat) -> CGFloat {
        guard zoomTransitionEnabled else { return 1 }
        if showingArticle { return 1 }
        return rowHeight / height
    }

    private func phoneArticleAnchor(rowY: CGFloat, rowHeight: CGFloat, height: CGFloat) -> UnitPoint {
        guard zoomTransitionEnabled else { return .center }
        let denominator = max(height - rowHeight, 0.001)
        return UnitPoint(x: 0.5, y: rowY / denominator)
    }

    private func phoneArticleOffsetX(width: CGFloat) -> CGFloat {
        if zoomTransitionEnabled { return 0 }
        return showingArticle ? 0 : width
    }

    private var phoneArticleOpacity: Double {
        if zoomTransitionEnabled {
            return showingArticle ? 1 : 0
        }
        return 1
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
