import SwiftUI

struct BrowserSuggestedFeedRow: View {

    let site: SuggestedSite
    let isAdded: Bool
    let isAdding: Bool
    let onAdd: () -> Void

    private var domain: String {
        guard let host = URL(string: site.feedUrl)?.host() else { return site.feedUrl }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.title)
                        .font(.body)
                        .lineLimit(1)
                    Text(domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                status
                    .frame(
                        width: BrowserSuggestionRow.iconSize,
                        height: BrowserSuggestionRow.iconSize
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isAdded || isAdding)
    }

    @ViewBuilder
    private var status: some View {
        if isAdded {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        } else if isAdding {
            ProgressView()
        } else {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.accent)
        }
    }
}
