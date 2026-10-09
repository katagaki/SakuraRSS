import SwiftUI

struct HideReadContentButton: View {

    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label(String(localized: "HideReadContent", table: "Articles"), systemImage: "eye.slash")
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .compatibleGlassButtonStyle()
        .buttonBorderShape(.capsule)
    }
}
