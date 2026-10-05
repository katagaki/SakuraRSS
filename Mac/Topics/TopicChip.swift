import SwiftUI

struct TopicChip: View {

    let name: String
    let count: Int
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .foregroundStyle(.tint)
                Text(name)
                Text(count.formatted())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quinary, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
