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
    @Environment(\.feedBackgroundColors) private var feedColors

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
