import SwiftUI

struct StorageBarSection: View {

    let deviceStats: DeviceStorageStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StorageBar(
                segments: barSegments,
                totalCapacity: deviceStats?.totalCapacity ?? 0
            )
            StorageLegend(segments: barSegments)
        }
        .padding(.vertical, 8)
    }

    private var sakuraSegments: [StorageSegment] {
        let breakdown = deviceStats?.breakdown ?? SakuraStorageBreakdown(
            feedsBytes: 0, podcastsBytes: 0, cacheBytes: 0
        )
        return [
            StorageSegment(
                kind: .sakura,
                label: String(localized: "Storage.Usage.Feeds", table: "DataManagement"),
                color: .pink,
                bytes: breakdown.feedsBytes
            ),
            StorageSegment(
                kind: .sakura,
                label: String(localized: "Storage.Usage.Podcasts", table: "DataManagement"),
                color: .purple,
                bytes: breakdown.podcastsBytes
            ),
            StorageSegment(
                kind: .sakura,
                label: String(localized: "Storage.Usage.Cache", table: "DataManagement"),
                color: .blue,
                bytes: breakdown.cacheBytes
            )
        ]
    }

    private var barSegments: [StorageSegment] {
        guard let stats = deviceStats, stats.totalCapacity > 0 else {
            return sakuraSegments
        }
        var segments: [StorageSegment] = [
            StorageSegment(
                kind: .other,
                label: String(localized: "Storage.Usage.OtherApps", table: "DataManagement"),
                color: .gray,
                bytes: stats.usedByOtherApps
            )
        ]
        segments.append(contentsOf: sakuraSegments)
        segments.append(StorageSegment(
            kind: .free,
            label: String(localized: "Storage.Usage.Free", table: "DataManagement"),
            color: Color(uiColor: .systemGray5),
            bytes: stats.availableCapacity
        ))
        return segments
    }
}

struct StorageSegment: Identifiable, Sendable {
    enum Kind { case sakura, other, free }
    let id = UUID()
    let kind: Kind
    let label: String
    let color: Color
    let bytes: Int64
}

private struct StorageBar: View {

    let segments: [StorageSegment]
    let totalCapacity: Int64

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    let width = widthFor(segment, totalWidth: geometry.size.width)
                    if width > 0 {
                        segment.color
                            .frame(width: width)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 16)
    }

    private func widthFor(_ segment: StorageSegment, totalWidth: CGFloat) -> CGFloat {
        let denominator = denominator
        guard denominator > 0 else { return 0 }
        let fraction = CGFloat(segment.bytes) / CGFloat(denominator)
        return max(0, totalWidth * fraction)
    }

    private var denominator: Int64 {
        if totalCapacity > 0 { return totalCapacity }
        return max(1, segments.reduce(0) { $0 + $1.bytes })
    }
}

private struct StorageLegend: View {

    let segments: [StorageSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(segments) { segment in
                HStack(spacing: 8) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 10, height: 10)
                    Text(segment.label)
                        .font(.subheadline)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: segment.bytes, countStyle: .file))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}
