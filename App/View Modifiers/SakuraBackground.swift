import SwiftUI

private struct FeedBackgroundColorsKey: EnvironmentKey {
    static let defaultValue: [Color] = []
}

private struct SakuraBackgroundDisabledKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var feedBackgroundColors: [Color] {
        get { self[FeedBackgroundColorsKey.self] }
        set { self[FeedBackgroundColorsKey.self] = newValue }
    }

    var isSakuraBackgroundDisabled: Bool {
        get { self[SakuraBackgroundDisabledKey.self] }
        set { self[SakuraBackgroundDisabledKey.self] = newValue }
    }
}

#if !os(visionOS) && !targetEnvironment(macCatalyst)
struct SakuraBackground: ViewModifier {

    @AppStorage("Display.SakuraBackground") private var sakuraBackgroundEnabled: Bool = true
    @AppStorage("Display.FeedBackground") private var feedBackgroundEnabled: Bool = true
    @Environment(\.feedBackgroundColors) private var feedColors
    @Environment(\.isSakuraBackgroundDisabled) private var isDisabled

    private var isActive: Bool { sakuraBackgroundEnabled && !isDisabled }

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(isActive ? .hidden : .automatic)
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    if isActive {
                        LinearGradient(
                            colors: [
                                Color("BackgroundGradientTop"),
                                Color("BackgroundGradientBottom")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    if feedBackgroundEnabled, !isDisabled, !feedColors.isEmpty {
                        FeedHeaderGradientView(colors: feedColors)
                            .frame(height: 360)
                    }
                }
                .ignoresSafeArea()
            }
    }
}
#endif

extension View {
    @ViewBuilder
    func sakuraBackground() -> some View {
        #if os(visionOS) || targetEnvironment(macCatalyst)
        self
        #else
        modifier(SakuraBackground())
        #endif
    }
}
