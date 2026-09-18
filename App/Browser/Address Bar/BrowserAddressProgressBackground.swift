import SwiftUI

/// The address bar's progress fill. Sits behind the label inside the bar's own
/// capsule, so a busy page tints the omnibox the way a browser tints its
/// location field rather than floating a separate pill over the page.
struct BrowserAddressProgressBackground: View {

    private static let marqueeBandFraction: CGFloat = 0.45

    private static let marquee: Animation =
        .linear(duration: 1.1).repeatForever(autoreverses: false)

    let progress: BrowserAddressProgress?
    @State private var isMarqueeRunning = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                switch progress {
                case .determinate(let fraction):
                    fill
                        .frame(width: proxy.size.width * fraction)
                        .animation(.smooth, value: fraction)
                case .indeterminate:
                    let band = proxy.size.width * BrowserAddressProgressBackground
                        .marqueeBandFraction
                    fill
                        .frame(width: band)
                        .mask { marqueeFalloff }
                        .offset(x: isMarqueeRunning ? proxy.size.width : -band)
                        .animation(BrowserAddressProgressBackground.marquee, value: isMarqueeRunning)
                        .onAppear { isMarqueeRunning = true }
                        .onDisappear { isMarqueeRunning = false }
                case nil:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(.capsule)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Fades the travelling band in and out along its length, so it reads as
    /// a sweep rather than a block sliding past. A mask rather than the fill's
    /// own gradient: the fill stays the bar's vertical one.
    private var marqueeFalloff: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.5),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var fill: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.42), Color.accentColor.opacity(0.22)],
            startPoint: .bottom,
            endPoint: .top
        )
        .transition(.opacity)
    }
}
