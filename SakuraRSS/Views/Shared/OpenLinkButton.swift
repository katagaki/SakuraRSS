import SwiftUI

struct OpenLinkButton: View {

    let title: LocalizedStringResource
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label(
                String(localized: title),
                systemImage: systemImage
            )
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
}
