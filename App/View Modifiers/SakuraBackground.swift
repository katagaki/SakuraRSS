import SwiftUI

private struct FeedBackgroundColorsKey: EnvironmentKey {
    static let defaultValue: [Color] = []
}

extension EnvironmentValues {
    var feedBackgroundColors: [Color] {
        get { self[FeedBackgroundColorsKey.self] }
        set { self[FeedBackgroundColorsKey.self] = newValue }
    }
}

struct SakuraBackground: ViewModifier {

    @AppStorage("Display.SakuraBackground") private var sakuraBackgroundEnabled: Bool = true
    @AppStorage("Display.FeedBackground") private var feedBackgroundEnabled: Bool = true
    @Environment(\.feedBackgroundColors) private var feedColors

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(sakuraBackgroundEnabled ? .hidden : .automatic)
            .background(alignment: .top) {
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
                    }
                    if feedBackgroundEnabled, !feedColors.isEmpty {
                        FeedHeaderGradientView(colors: feedColors)
                            .frame(height: 360)
                    }
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func sakuraBackground() -> some View {
        modifier(SakuraBackground())
    }
}
