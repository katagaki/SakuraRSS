import SwiftUI

struct FeedHeaderView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    @State private var favicon: UIImage?

    private let iconSize: CGFloat = 64
    private let iconCornerRadius: CGFloat = 14

    @Namespace private var namespace

    private var shareURL: URL? {
        let candidate = feed.siteURL.isEmpty ? feed.fetchURL : feed.siteURL
        return URL(string: candidate)
    }

    private var trimmedDescription: String {
        feed.feedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 8) {
            iconView
                .padding(.bottom, 4)

            VStack(spacing: 4) {
                Text(feed.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if !feed.domain.isEmpty {
                    Text(feed.domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if !trimmedDescription.isEmpty {
                Text(trimmedDescription)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }

            actionButtons
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .task(id: feed.id) {
            favicon = await FaviconCache.shared.favicon(for: feed)
        }
        .onChange(of: feedManager.faviconRevision) {
            Task { favicon = await FaviconCache.shared.favicon(for: feed) }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        Group {
            if let favicon {
                FaviconImage(
                    favicon,
                    size: iconSize,
                    cornerRadius: iconCornerRadius,
                    circle: feed.isCircleIcon,
                    skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                        || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: feed.domain)
                )
            } else if let data = feed.acronymIcon, let image = UIImage(data: data) {
                FaviconImage(
                    image,
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
        }
        .frame(width: iconSize, height: iconSize)
    }

    @ViewBuilder
    private var actionButtons: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        feedManager.toggleMuted(feed)
                    }
                } label: {
                    Text(feed.isMuted
                         ? String(localized: "FeedMenu.Unmute", table: "Feeds")
                         : String(localized: "FeedMenu.Mute", table: "Feeds"))
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.interpolate)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .glassEffectID("MuteToggle", in: namespace)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(String(localized: "FeedHeader.Share", table: "Feeds"))
                    .glassEffectID("Share", in: namespace)
                }
            }
        }
    }
}
