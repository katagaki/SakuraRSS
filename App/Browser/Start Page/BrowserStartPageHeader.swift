import SwiftUI
import Hanami

struct BrowserStartPageHeader: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "StartPage.Title", table: "Browser"))
                .font(.largeTitle.bold())
            Text(String(localized: "StartPage.Subtitle", table: "Browser"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
