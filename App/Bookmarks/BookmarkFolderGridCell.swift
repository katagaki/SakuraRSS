import SwiftUI
import Hanami

struct BookmarkFolderGridCell: View {

    @Environment(FeedManager.self) var feedManager
    let folder: BookmarkFolder

    private let cellSize: CGFloat = 56
    private let cellCornerRadius: CGFloat = 12

    private var folderTint: Color? {
        ListIcon(rawValue: folder.icon)?.gradientColors.0
    }

    private var thumbnailURLs: [URL] {
        _ = feedManager.dataRevision
        return feedManager.latestBookmarkThumbnailURLs(in: folder)
            .compactMap(URL.init(string:))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            cellContent
                .frame(width: cellSize, height: cellSize)
                .compatibleGlassEffect(
                    in: RoundedRectangle(cornerRadius: cellCornerRadius),
                    tint: folderTint?.opacity(0.3),
                    clear: false
                )
                .contentShape(
                    .hoverEffect,
                    AnyShape(RoundedRectangle(cornerRadius: cellCornerRadius))
                )
                .hoverEffect(.highlight)

            Text(folder.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var cellContent: some View {
        let urls = thumbnailURLs
        if urls.isEmpty {
            Color.clear
        } else {
            BookmarkThumbnailStack(thumbnailURLs: urls, containerSize: cellSize)
        }
    }
}

/// Up to three article thumbnails arranged like photos casually
/// stacked on top of each other, newest on top.
struct BookmarkThumbnailStack: View {

    let thumbnailURLs: [URL]
    let containerSize: CGFloat

    private let rotationDegrees: [Double] = [-3, 7, -9]

    private var thumbnailSize: CGFloat {
        containerSize * 0.58
    }

    var body: some View {
        ZStack {
            ForEach(Array(thumbnailURLs.prefix(3).enumerated().reversed()), id: \.offset) { entry in
                thumbnail(url: entry.element)
                    .rotationEffect(.degrees(rotationDegrees[entry.offset]))
            }
        }
        .frame(width: containerSize, height: containerSize)
        .drawingGroup()
    }

    private func thumbnail(url: URL) -> some View {
        CachedAsyncImage(url: url, maxPixelSize: 160) {
            Color.secondary.opacity(0.2)
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(.white, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
    }
}
