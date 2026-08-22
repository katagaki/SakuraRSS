import SwiftUI

struct LastUpdatedLabel: View {

    let date: Date?

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private var text: String {
        LastUpdatedText.text(for: date)
    }
}
