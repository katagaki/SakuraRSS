import SwiftUI

struct BrowserStartPageSectionHeader: View {

    let title: String

    var body: some View {
        Text(title)
            // Matches Today's own section headers, which sit directly below.
            .font(.title3)
            .fontWeight(.bold)
    }
}
