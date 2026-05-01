import SwiftUI

struct TodayTabBar: View {

    let tabs: [TodayTabItem]
    @Binding var selection: HomeSelection
    @Binding var tabFrames: [String: CGRect]

    private var indicatorFrame: CGRect {
        tabFrames[selection.rawValue] ?? .zero
    }

    private var indicatorColor: Color {
        switch selection {
        case .section(let section): section.tabAccentColor
        case .list: .accentColor
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        TodayTabButton(
                            tab: tab,
                            isSelected: tab.matches(selection)
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
                                    key: TodayTabFrameKey.self,
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
                        .fill(indicatorColor)
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
                        .animation(.smooth.speed(2.0), value: indicatorColor)
                }
                .onPreferenceChange(TodayTabFrameKey.self) { newFrames in
                    tabFrames.merge(newFrames, uniquingKeysWith: { _, new in new })
                }
            }
            .clipShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
            .onAppear {
                guard let selected = tabs.first(where: { $0.matches(selection) }) else { return }
                proxy.scrollTo(selected.id, anchor: .center)
            }
        }
    }

    private static let coordinateSpaceID = "TodayTabBar"
}

private struct TodayTabFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TodayTabButton: View {

    let tab: TodayTabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
