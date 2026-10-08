import SwiftUI

struct TodayQuickAccessEndEditingButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(localized: "Today.QuickAccess.EndEditing", table: "Home"))
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .compatibleGlassButtonStyle()
    }
}
