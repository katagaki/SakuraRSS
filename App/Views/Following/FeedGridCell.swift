import SwiftUI

struct FeedGridCell: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    var isWiggling: Bool = false
    var onDelete: (() -> Void)?
    var onTap: (() -> Void)?
    @State private var favicon: UIImage?

    private let iconSize: CGFloat = 56

    private var iconCornerRadius: CGFloat { 12 }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            VStack(alignment: .center, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    if let favicon = favicon {
                        FaviconImage(
                            favicon,
                            size: iconSize,
                            cornerRadius: iconCornerRadius,
                            circle: feed.isCircleIcon,
                            skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                            || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: feed.domain)
                        )
                    } else if let data = feed.acronymIcon, let acronym = UIImage(data: data) {
                        FaviconImage(
                            acronym,
                            size: iconSize,
                            cornerRadius: iconCornerRadius,
                            circle: feed.isCircleIcon,
                            skipInset: true
                        )
                    } else {
                        InitialsAvatarView(
                            feed.title,
                            size: iconSize,
                            circle: feed.isCircleIcon,
                            cornerRadius: iconCornerRadius
                        )
                    }

                    if feed.isXFeed {
                        FaviconProgressBadge(
                            lastFetched: feed.lastFetched,
                            cooldown: FeedManager.xRefreshInterval,
                            size: 15
                        )
                        .offset(x: 3, y: 3)
                    } else if feed.isInstagramFeed {
                        FaviconProgressBadge(
                            lastFetched: feed.lastFetched,
                            cooldown: FeedManager.instagramRefreshInterval,
                            size: 15
                        )
                        .offset(x: 3, y: 3)
                    }
                }
                .frame(width: iconSize, height: iconSize)
                .drawingGroup()
                .overlay(alignment: .topTrailing) {
                    if feedManager.unreadCount(for: feed) > 0 {
                        unreadDot
                            .offset(
                                x: feed.isCircleIcon ? 0 : 4,
                                y: feed.isCircleIcon ? 0 : -4
                            )
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isWiggling, onDelete != nil {
                        deleteBadge
                            .offset(x: -10, y: -10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Group {
                    if feed.isMuted {
                        Text("\(feed.title) \(Image(systemName: "bell.slash.fill"))")
                    } else {
                        Text(feed.title)
                    }
                }
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)
            }
            .wiggle(isWiggling, seed: Double(feed.id % 17) / 17.0)
        }
        .frame(maxWidth: .infinity)
        .feedGridCellTap(onTap)
        .task {
            favicon = await loadFavicon()
        }
        .onChange(of: feedManager.faviconRevision) {
            Task {
                favicon = await loadFavicon()
            }
        }
    }

    private func loadFavicon() async -> UIImage? {
        let currentFeed = feedManager.feedsByID[feed.id] ?? feed
        return await FaviconCache.shared.favicon(for: currentFeed)
    }

    private var unreadDot: some View {
        Circle()
            .fill(.blue.gradient)
            .frame(width: 12, height: 12)
            .overlay {
                Circle().strokeBorder(.blue, lineWidth: 0.5)
            }
    }

    private var mutedBadge: some View {
        Image(systemName: "bell.slash.fill")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(.background)
            .frame(width: 16, height: 16)
            .background(.primary, in: .circle)
            .overlay {
                Circle().strokeBorder(.separator, lineWidth: 0.5)
            }
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
        .accessibilityLabel(String(localized: "FeedEditSheet.DeleteFeed", table: "Feeds"))
    }
}
