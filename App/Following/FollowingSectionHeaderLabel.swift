import SwiftUI
import Hanami

struct FollowingSectionHeaderLabel: View {

    let section: FeedSection
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Text(section.localizedTitle)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
