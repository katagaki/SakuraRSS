import SwiftUI

private struct TodayLeadingContentInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Extra leading inset applied to Today section content so the landscape
    /// layout can lay sections out beside the leading column while letting
    /// full-width carousels scroll beneath it.
    var todayLeadingContentInset: CGFloat {
        get { self[TodayLeadingContentInsetKey.self] }
        set { self[TodayLeadingContentInsetKey.self] = newValue }
    }
}

private struct TodayHorizontalContentPadding: ViewModifier {
    @Environment(\.todayLeadingContentInset) private var leadingContentInset
    let basePadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.leading, basePadding + leadingContentInset)
            .padding(.trailing, basePadding)
    }
}

extension View {
    func todayHorizontalContentPadding(_ basePadding: CGFloat = 16) -> some View {
        modifier(TodayHorizontalContentPadding(basePadding: basePadding))
    }
}
