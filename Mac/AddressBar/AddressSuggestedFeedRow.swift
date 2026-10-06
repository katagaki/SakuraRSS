import SwiftUI

struct AddressSuggestedFeedRow: View {

    let site: SuggestedSite
    let isAdded: Bool
    let isAdding: Bool
    let onAdd: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(site.title)
                        .lineLimit(1)
                    Text(site.domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                status
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isHovering && !isAdded ? Color.primary.opacity(0.08) : .clear,
                in: .rect(cornerRadius: 6)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isAdded || isAdding)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var status: some View {
        if isAdded {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        } else if isAdding {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
        }
    }
}
