import SwiftUI

struct AddFeedListMembershipSection: View {

    let lists: [FeedList]
    let addedFeedIDs: Set<Int64>
    let listMembership: [Int64: Set<Int64>]
    let onToggle: (FeedList) -> Void

    var body: some View {
        Section {
            ForEach(lists) { list in
                Button {
                    onToggle(list)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: list.icon)
                            .foregroundStyle(.accent)
                            .frame(width: 24)
                        Text(list.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if addedFeedIDs.allSatisfy({
                            listMembership[list.id]?.contains($0) == true
                        }) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "AddFeed.Section.AddToList", table: "Feeds"))
        }
    }
}
