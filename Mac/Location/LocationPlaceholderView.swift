import SwiftUI

struct LocationPlaceholderView: View {

    let title: String
    let symbolName: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbolName)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
