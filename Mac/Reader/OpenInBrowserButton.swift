import SwiftUI

struct OpenInBrowserButton: View {

    @Environment(\.openURL) private var openURL
    let url: URL?
    let titleKey: String.LocalizationValue

    var body: some View {
        if let url {
            Button {
                openURL(url)
            } label: {
                Label(String(localized: titleKey, table: "Articles"), systemImage: "safari")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.quinary, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}
