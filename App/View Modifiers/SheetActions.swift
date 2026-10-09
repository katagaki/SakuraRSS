import SwiftUI

extension View {

    /// A sheet's cancel and confirm buttons: in the top bar on iOS, and along
    /// the bottom on macOS, where a toolbar would put them at the top.
    func sheetActions<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        modifier(SheetActionsModifier(leading: leading(), trailing: trailing()))
    }
}

private struct SheetActionsModifier<Leading: View, Trailing: View>: ViewModifier {

    let leading: Leading
    let trailing: Trailing

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SheetActionBar {
                    leading
                        .keyboardShortcut(.cancelAction)
                    trailing
                        .keyboardShortcut(.defaultAction)
                }
            }
        #else
        content
            .toolbar {
                ToolbarItem(placement: .sheetLeading) {
                    leading
                }
                ToolbarItem(placement: .sheetTrailing) {
                    trailing
                }
            }
        #endif
    }
}

/// The bottom row of buttons on a macOS sheet, aligned trailing.
struct SheetActionBar<Buttons: View>: View {

    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                buttons()
            }
            .padding(16)
        }
        .background(.background)
    }
}
