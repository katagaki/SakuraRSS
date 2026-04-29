import SwiftUI

struct FeedGridCellTapModifier: ViewModifier {
    let onTap: (() -> Void)?

    func body(content: Content) -> some View {
        if let onTap {
            content
                .contentShape(.rect)
                .onTapGesture { onTap() }
        } else {
            content
        }
    }
}

extension View {
    func feedGridCellTap(_ onTap: (() -> Void)?) -> some View {
        modifier(FeedGridCellTapModifier(onTap: onTap))
    }
}
