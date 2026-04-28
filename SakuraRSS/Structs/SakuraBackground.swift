import SwiftUI

struct SakuraBackground: ViewModifier {

    @AppStorage("Display.SakuraBackground") private var sakuraBackgroundEnabled: Bool = true

    @ViewBuilder
    func body(content: Content) -> some View {
        if sakuraBackgroundEnabled {
            content
                .scrollContentBackground(.hidden)
                .background {
                    LinearGradient(
                        colors: [
                            Color("BackgroundGradientTop"),
                            Color("BackgroundGradientBottom")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
        } else {
            content
        }
    }
}

extension View {
    func sakuraBackground() -> some View {
        modifier(SakuraBackground())
    }
}
