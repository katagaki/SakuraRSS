import SwiftUI

struct RecentSearchesSection: View {

    let searches: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "Discover.RecentSearches", table: "Feeds"))
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(String(localized: "Discover.ClearHistory", table: "Feeds")) {
                    withAnimation(.smooth.speed(2.0)) {
                        onClear()
                    }
                }
                .font(.title3)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(searches, id: \.self) { term in
                    RecentSearchRow(term: term) {
                        onSelect(term)
                    }
                    if term != searches.last {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct RecentSearchRow: View {

    let term: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .frame(width: 20)
                Text(term)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
