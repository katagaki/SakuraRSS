import SwiftUI

#if !os(visionOS) && !targetEnvironment(macCatalyst)
struct FeedPreviewContent: View {

    let style: FeedDisplayStyle
    let deviceWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            FeedHeaderPlaceholder(deviceWidth: deviceWidth)
                .padding(.top, deviceWidth * 0.12)
                .padding(.bottom, deviceWidth * 0.10)
            VStack(spacing: deviceWidth * 0.03) {
                ForEach(0..<3, id: \.self) { _ in
                    rowPlaceholder
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, deviceWidth * 0.05)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var rowPlaceholder: some View {
        switch style {
        case .compact:
            CompactRowPlaceholder(deviceWidth: deviceWidth)
        case .feed:
            FeedRowPlaceholder(deviceWidth: deviceWidth)
        default:
            InboxRowPlaceholder(deviceWidth: deviceWidth)
        }
    }
}

private let primaryShade: Color = .primary.opacity(0.35)
private let secondaryShade: Color = .primary.opacity(0.18)

struct ArticlePreviewContent: View {

    let deviceWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: deviceWidth * 0.025) {
            RoundedRectangle(cornerRadius: deviceWidth * 0.02, style: .continuous)
                .fill(secondaryShade)
                .frame(height: deviceWidth * 0.32)
            VStack(alignment: .leading, spacing: deviceWidth * 0.018) {
                Capsule()
                    .fill(secondaryShade)
                    .frame(height: deviceWidth * 0.018)
                Capsule()
                    .fill(secondaryShade)
                    .frame(height: deviceWidth * 0.018)
                Capsule()
                    .fill(secondaryShade)
                    .frame(width: deviceWidth * 0.55, height: deviceWidth * 0.018)
            }
        }
        .padding(.horizontal, deviceWidth * 0.04)
        .padding(.top, deviceWidth * 0.08)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

private struct FeedHeaderPlaceholder: View {

    let deviceWidth: CGFloat

    var body: some View {
        VStack(spacing: deviceWidth * 0.025) {
            RoundedRectangle(cornerRadius: deviceWidth * 0.05, style: .continuous)
                .fill(primaryShade)
                .frame(width: deviceWidth * 0.18, height: deviceWidth * 0.18)
            Capsule()
                .fill(primaryShade)
                .frame(width: deviceWidth * 0.42, height: deviceWidth * 0.04)
            Capsule()
                .fill(secondaryShade)
                .frame(width: deviceWidth * 0.28, height: deviceWidth * 0.025)
        }
    }
}

private struct InboxRowPlaceholder: View {

    let deviceWidth: CGFloat

    var body: some View {
        HStack(spacing: deviceWidth * 0.03) {
            RoundedRectangle(cornerRadius: deviceWidth * 0.025, style: .continuous)
                .fill(secondaryShade)
                .frame(width: deviceWidth * 0.13, height: deviceWidth * 0.13)
            VStack(alignment: .leading, spacing: deviceWidth * 0.015) {
                Capsule()
                    .fill(primaryShade)
                    .frame(height: deviceWidth * 0.025)
                Capsule()
                    .fill(secondaryShade)
                    .frame(height: deviceWidth * 0.02)
                Capsule()
                    .fill(secondaryShade)
                    .frame(width: deviceWidth * 0.45, height: deviceWidth * 0.02)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct CompactRowPlaceholder: View {

    let deviceWidth: CGFloat

    var body: some View {
        HStack(spacing: deviceWidth * 0.03) {
            Capsule()
                .fill(primaryShade)
                .frame(width: deviceWidth * 0.55, height: deviceWidth * 0.025)
            Spacer(minLength: 0)
            Capsule()
                .fill(secondaryShade)
                .frame(width: deviceWidth * 0.1, height: deviceWidth * 0.02)
        }
        .padding(.vertical, deviceWidth * 0.015)
    }
}

private struct FeedRowPlaceholder: View {

    let deviceWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: deviceWidth * 0.02) {
            HStack(spacing: deviceWidth * 0.02) {
                Circle()
                    .fill(secondaryShade)
                    .frame(width: deviceWidth * 0.06, height: deviceWidth * 0.06)
                Capsule()
                    .fill(primaryShade)
                    .frame(width: deviceWidth * 0.25, height: deviceWidth * 0.025)
                Spacer(minLength: 0)
            }
            Capsule()
                .fill(primaryShade)
                .frame(height: deviceWidth * 0.025)
            Capsule()
                .fill(secondaryShade)
                .frame(width: deviceWidth * 0.6, height: deviceWidth * 0.02)
            RoundedRectangle(cornerRadius: deviceWidth * 0.025, style: .continuous)
                .fill(secondaryShade)
                .frame(height: deviceWidth * 0.22)
        }
    }
}
#endif
