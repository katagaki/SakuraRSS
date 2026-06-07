import SwiftUI
import Hanami

struct HomeSectionBar: View {

    let tabs: [HomeSectionBarItem]
    let selectionStore: HomeSelectionStore

    @State private var tabFrames: [String: CGRect] = [:]
    @State private var hasPerformedInitialScroll = false

    private let deloreanClock = DeloreanClock.shared

    private var selection: HomeSelection {
        selectionStore.selection
    }

    private var indicatorFrame: CGRect {
        tabFrames[selection.rawValue] ?? .zero
    }

    private var indicatorStyle: AnyShapeStyle {
        if case .section(.today) = selection {
            return AnyShapeStyle(TodayGreeting.periodGradient(at: deloreanClock.currentDate))
        }
        switch selection {
        case .section(let section): return section.tabAccentStyle
        case .list:
            let iconName = tabs.first(where: { $0.matches(selection) })?.listIconName
            if let iconName, let icon = ListIcon(rawValue: iconName) {
                return AnyShapeStyle(icon.gradient)
            }
            return AnyShapeStyle(Color.accentColor)
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
                            selectionStore.selection = tab.selection
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
                }
                .onPreferenceChange(HomeSectionBarFrameKey.self) { newFrames in
                    tabFrames.merge(newFrames, uniquingKeysWith: { _, new in new })
                }
            }
            // Glass sits behind the scroll content rather than wrapping it, so a
            // programmatic scroll repaints instead of leaving a stale composite.
            #if os(visionOS)
            .background(.regularMaterial, in: .capsule)
            #else
            .background {
                Color.clear.compatibleGlassEffect(in: .capsule, interactive: true)
            }
            #endif
            .clipShape(.capsule)
            .onChange(of: tabFrames, initial: true) {
                guard !hasPerformedInitialScroll,
                      tabFrames[selection.rawValue] != nil else { return }
                hasPerformedInitialScroll = true
                scrollSelectionIntoView(proxy, animated: false)
            }
            .onChange(of: selection) {
                scrollSelectionIntoView(proxy, animated: true)
            }
        }
    }

    @MainActor
    private func scrollSelectionIntoView(_ proxy: ScrollViewProxy, animated: Bool) {
        let target = selection.rawValue
        Task { @MainActor in
            if animated {
                withAnimation(.smooth.speed(2.0)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            } else {
                proxy.scrollTo(target, anchor: .center)
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
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .hidden()
                .overlay {
                    Text(tab.title)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? selectedTextColor : Color.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
