import SwiftUI

struct FeedImageTitleOverlay: View {

    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6), in: .rect(cornerRadius: 6))
            .padding(8)
    }
}
