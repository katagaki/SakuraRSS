import SwiftUI

/// Wrapping pill row showing topics and people, capped at 20 items combined
/// to keep the Today tab compact.
struct TodayChipsFlow: View {

    let topics: [(name: String, count: Int)]
    let people: [(name: String, count: Int)]

    var body: some View {
        TodayFlowLayout(spacing: 8) {
            ForEach(topics, id: \.name) { topic in
                NavigationLink(value: EntityDestination(name: topic.name, types: ["organization", "place"])) {
                    chip(topic.name)
                }
                .buttonStyle(.plain)
            }
            ForEach(people, id: \.name) { person in
                NavigationLink(value: EntityDestination(name: person.name, types: ["person"])) {
                    chip(person.name)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chip(_ name: String) -> some View {
        Text(name)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .foregroundStyle(.primary)
    }
}

struct TodayFlowLayout: Layout {

    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
