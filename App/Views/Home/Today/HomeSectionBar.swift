import SwiftUI

struct HomeSectionBar: View {

    let tabs: [HomeSectionBarItem]
    @Binding var selection: HomeSelection
    @Binding var tabFrames: [String: CGRect]

    private let deloreanClock = DeloreanClock.shared

    private var indicatorFrame: CGRect {
        tabFrames[selection.rawValue] ?? .zero
    }

    private var indicatorStyle: AnyShapeStyle {
        if case .section(.today) = selection {
            return AnyShapeStyle(TodayGreeting.periodGradient(at: deloreanClock.currentDate))
        }
        switch selection {
        case .section(let section): return section.tabAccentStyle
        case .list: return AnyShapeStyle(Color.accentColor)
        case .topic: return AnyShapeStyle(Color.accentColor)
        }
    }

    private func selectedTextColor(for tab: HomeSectionBarItem) -> Color {
        switch tab.selection {
        case .section(let section): section.tabSelectedTextColor
        case .list, .topic: .white
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        HomeSectionBarButton(
                            tab: tab,
                            isSelected: tab.matches(selection),
                            selectedTextColor: selectedTextColor(for: tab)
                        ) {
                            selection = tab.selection
                            withAnimation(.smooth.speed(2.0)) {
                                proxy.scrollTo(tab.id, anchor: .center)
                            }
                        }
                        .id(tab.id)
                        .background {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: HomeSectionBarFrameKey.self,
                                    value: [tab.id: geo.frame(in: .named(Self.coordinateSpaceID))]
                                )
                            }
                        }
                    }
                }
                .padding(4)
                .coordinateSpace(name: Self.coordinateSpaceID)
                .background(alignment: .topLeading) {
                    Capsule()
                        .fill(indicatorStyle)
                        .frame(
                            width: indicatorFrame.width,
                            height: indicatorFrame.height
                        )
                        .offset(
                            x: indicatorFrame.minX,
                            y: indicatorFrame.minY
                        )
                        .opacity(indicatorFrame.width > 0 ? 1 : 0)
                        .animation(.smooth.speed(2.0), value: indicatorFrame)
                        .animation(.smooth.speed(2.0), value: selection)
                }
                .onPreferenceChange(HomeSectionBarFrameKey.self) { newFrames in
                    tabFrames.merge(newFrames, uniquingKeysWith: { _, new in new })
                }
            }
            .clipShape(.capsule)
            #if os(visionOS)
            .background(.regularMaterial, in: .capsule)
            #else
            .compatibleGlassEffect(in: .capsule, interactive: true)
            #endif
            .onAppear {
                guard let selected = tabs.first(where: { $0.matches(selection) }) else { return }
                proxy.scrollTo(selected.id, anchor: .center)
            }
        }
    }

    private static let coordinateSpaceID = "HomeSectionBar"
}

private struct HomeSectionBarFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct HomeSectionBarButton: View {

    let tab: HomeSectionBarItem
    let isSelected: Bool
    let selectedTextColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.title)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? selectedTextColor : Color.primary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
