import SwiftUI

struct FeedStorageSection: View {

    let feedSizes: [(feed: Feed, bytes: Int64)]
    let isLoading: Bool

    var body: some View {
        Section {
            if isLoading && feedSizes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                ForEach(feedSizes, id: \.feed.id) { entry in
                    StorageFeedRow(feed: entry.feed, bytes: entry.bytes)
                }
            }
        } header: {
            Text(String(localized: "Storage.Usage.FeedsHeader", table: "DataManagement"))
        } footer: {
            Text(String(localized: "Storage.Usage.FeedsFooter", table: "DataManagement"))
        }
    }
}
