import SwiftUI

struct FollowingListGridCell: View {

    @Environment(FeedManager.self) var feedManager
    let list: FeedList
    var isWiggling: Bool = false
    var onDelete: (() -> Void)?
    var onTap: (() -> Void)?

    private let iconSize: CGFloat = 56
    private let iconCornerRadius: CGFloat = 12
    private let iconInnerPadding: CGFloat = 8
    private let gridSpacing: CGFloat = 4

    private var listTint: Color? {
        ListIcon(rawValue: list.icon)?.gradientColors.0
    }

    private var miniIconSize: CGFloat {
        let inner = iconSize - (iconInnerPadding * 2)
        return (inner - gridSpacing) / 2
    }

    private var miniIconCornerRadius: CGFloat {
        iconCornerRadius * miniIconSize / iconSize
    }

    private var feedsInList: [Feed] {
        _ = feedManager.dataRevision
        let ids = feedManager.feedIDs(for: list)
        let ordered = feedManager.feeds.filter { ids.contains($0.id) }
        return Array(ordered.prefix(4))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            feedGrid
                .padding(iconInnerPadding)
                .frame(width: iconSize, height: iconSize)
                .drawingGroup()
                .compatibleGlassEffect(
                    in: RoundedRectangle(cornerRadius: iconCornerRadius),
                    tint: listTint?.opacity(0.3),
                    clear: false
                )
                .contentShape(
                    .hoverEffect,
                    AnyShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                )
                .hoverEffect(.highlight)
                .overlay(alignment: .topTrailing) {
                    if !isWiggling, feedManager.unreadCount(for: list) > 0 {
                        unreadDot
                            .offset(x: 4, y: -4)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isWiggling, onDelete != nil {
                        deleteBadge
                            .offset(x: -10, y: -10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

            Text(list.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .feedGridCellTap(onTap)
    }

    private var deleteBadge: some View {
        Button {
            onDelete?()
        } label: {
            Color.clear
                .frame(width: 24, height: 24)
                .background(.thinMaterial, in: .circle)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                .overlay {
                    Circle().strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                }
                .overlay {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "ListMenu.Delete", table: "Lists"))
    }

    @ViewBuilder
    private var feedGrid: some View {
        let feeds = feedsInList
        VStack(spacing: gridSpacing) {
            HStack(spacing: gridSpacing) {
                gridSlot(feed: feeds.indices.contains(0) ? feeds[0] : nil)
                gridSlot(feed: feeds.indices.contains(1) ? feeds[1] : nil)
            }
            HStack(spacing: gridSpacing) {
                gridSlot(feed: feeds.indices.contains(2) ? feeds[2] : nil)
                gridSlot(feed: feeds.indices.contains(3) ? feeds[3] : nil)
            }
        }
    }

    @ViewBuilder
    private func gridSlot(feed: Feed?) -> some View {
        if let feed {
            FeedIcon(feed: feed, size: miniIconSize, cornerRadius: miniIconCornerRadius)
                .id(feed.id)
        } else {
            Color.clear
                .frame(width: miniIconSize, height: miniIconSize)
        }
    }

    private var unreadDot: some View {
        Circle()
            .fill(.blue.gradient)
            .frame(width: 12, height: 12)
            .overlay {
                Circle().strokeBorder(.blue, lineWidth: 0.5)
            }
    }
}
