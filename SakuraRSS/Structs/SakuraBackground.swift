import SwiftUI

struct SakuraBackground: ViewModifier {

    func body(content: Content) -> some View {
        content
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
    }
}

extension View {
    func sakuraBackground() -> some View {
        modifier(SakuraBackground())
    }
}
