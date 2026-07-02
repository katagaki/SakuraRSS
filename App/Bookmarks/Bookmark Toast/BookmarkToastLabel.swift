import SwiftUI

struct BookmarkToastLabel: View {

    let showsFolderHint: Bool

    var body: some View {
        HStack(spacing: 8.0) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(.tint)
            Text("BookmarkToast.Bookmarked", tableName: "Articles")
                .foregroundStyle(.primary)
            if showsFolderHint {
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 18.0)
        .padding(.vertical, 12.0)
        .contentShape(.capsule)
        #if os(visionOS)
        .background(.regularMaterial, in: Capsule())
        #else
        .compatibleGlassEffect(in: Capsule(), interactive: true)
        #endif
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
