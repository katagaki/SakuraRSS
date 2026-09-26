import SwiftUI

/// The address bar's progress fill. Sits behind the label inside the bar's own
/// capsule, so a busy page tints the omnibox the way a browser tints its
/// location field rather than floating a separate pill over the page.
struct BrowserAddressProgressBackground: View {

    private static let marqueeBandFraction: CGFloat = 0.6

    private static let marquee: Animation =
        .linear(duration: 1.6).repeatForever(autoreverses: false)

    /// A three-stop ramp meets its own peak at an angle, and that crease is
    /// what the eye follows across the bar. Smoothstepped samples flatten the
    /// band's ends and its crown, leaving nothing to track but the light.
    private static let falloffStops: [Gradient.Stop] = (0...16).map { step in
        let position = Double(step) / 16
        let distance = abs(position - 0.5) * 2
        let eased = 1 - (distance * distance * (3 - 2 * distance))
        return Gradient.Stop(color: .white.opacity(eased), location: position)
    }

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
            stops: BrowserAddressProgressBackground.falloffStops,
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
