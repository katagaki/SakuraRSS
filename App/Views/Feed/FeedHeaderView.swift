import SwiftUI

struct FeedHeaderView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    @State private var icon: UIImage?
    @State private var isEditingFeed: Bool = false
    @State private var isDescriptionExpanded: Bool = false
    @State private var isShowingUnfollowAlert: Bool = false

    private let iconSize: CGFloat = 64
    private let iconCornerRadius: CGFloat = 14

    @Namespace private var namespace
    @Namespace private var editNamespace

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
                    .lineLimit(isDescriptionExpanded ? nil : 3)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .contentShape(.rect)
                    .onTapGesture {
                        isDescriptionExpanded.toggle()
                    }
            }

            actionButtons
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .task(id: feed.id) {
            icon = await IconCache.shared.icon(for: feed)
        }
        .onChange(of: feedManager.iconRevision) {
            Task { icon = await IconCache.shared.icon(for: feed) }
        }
        .sheet(isPresented: $isEditingFeed) {
            EditFeedSheet(feedID: feed.id)
                .environment(feedManager)
                .navigationTransition(.zoom(sourceID: feed.id, in: editNamespace))
        }
        .alert(
            String(localized: "FeedMenu.Unfollow.Title", table: "Feeds"),
            isPresented: $isShowingUnfollowAlert
        ) {
            Button(String(localized: "FeedMenu.Unfollow.Confirm", table: "Feeds"),
                   role: .destructive) {
                try? feedManager.deleteFeed(feed)
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "FeedMenu.Unfollow.Message.\(feed.title)", table: "Feeds"))
        }
    }

    @ViewBuilder
    private var iconView: some View {
        Group {
            if let icon {
                IconImage(
                    icon,
                    size: iconSize,
                    cornerRadius: iconCornerRadius,
                    circle: feed.isCircleIcon,
                    skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                )
            } else if let data = feed.acronymIcon, let image = UIImage(data: data) {
                IconImage(
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
        CompatibleGlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

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
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.capsule)
                .compatibleGlassEffectID("MuteToggle", in: namespace)

                Button {
                    isEditingFeed = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 36)
                        .matchedTransitionSource(id: feed.id, in: editNamespace)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.circle)
                .accessibilityLabel(String(localized: "FeedHeader.Edit", table: "Feeds"))
                .compatibleGlassEffectID("Edit", in: namespace)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 36)
                    }
                    .compatibleGlassButtonStyle()
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(String(localized: "FeedHeader.Share", table: "Feeds"))
                    .compatibleGlassEffectID("Share", in: namespace)
                }

                Button(role: .destructive) {
                    isShowingUnfollowAlert = true
                } label: {
                    Image("dot.radiowaves.up.forward.slash")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 36)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.circle)
                .tint(.red)
                .accessibilityLabel(String(localized: "FeedMenu.Unfollow", table: "Feeds"))
                .compatibleGlassEffectID("Unfollow", in: namespace)

                Spacer(minLength: 0)
            }
        }
    }
}
