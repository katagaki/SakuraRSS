import SwiftUI

private struct FeedBackgroundColorsKey: EnvironmentKey {
    static let defaultValue: [Color] = []
}

private struct FeedBackgroundScrollOffsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var feedBackgroundColors: [Color] {
        get { self[FeedBackgroundColorsKey.self] }
        set { self[FeedBackgroundColorsKey.self] = newValue }
    }
    var feedBackgroundScrollOffset: CGFloat {
        get { self[FeedBackgroundScrollOffsetKey.self] }
        set { self[FeedBackgroundScrollOffsetKey.self] = newValue }
    }
}

struct SakuraBackground: ViewModifier {

    @AppStorage("Display.SakuraBackground") private var sakuraBackgroundEnabled: Bool = true
    @Environment(\.feedBackgroundColors) private var feedColors
    @Environment(\.feedBackgroundScrollOffset) private var feedScrollOffset

    @ViewBuilder
    func body(content: Content) -> some View {
        if sakuraBackgroundEnabled {
            content
                .scrollContentBackground(.hidden)
                .background(alignment: .top) {
                    ZStack(alignment: .top) {
                        LinearGradient(
                            colors: [
                                Color("BackgroundGradientTop"),
                                Color("BackgroundGradientBottom")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        if !feedColors.isEmpty {
                            FeedHeaderGradientView(colors: feedColors)
                                .frame(height: 360)
                                .offset(y: -max(0, feedScrollOffset))
                        }
                    }
                    .ignoresSafeArea()
                }
        } else {
            content
                .background(alignment: .top) {
                    if !feedColors.isEmpty {
                        FeedHeaderGradientView(colors: feedColors)
                            .frame(height: 360)
                            .offset(y: -max(0, feedScrollOffset))
                            .ignoresSafeArea(edges: [.top, .horizontal])
                    }
                }
        }
    }
}

extension View {
    func sakuraBackground() -> some View {
        modifier(SakuraBackground())
    }
}
