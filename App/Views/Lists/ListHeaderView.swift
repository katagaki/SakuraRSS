import SwiftUI

struct ListHeaderView: View {

    @Environment(FeedManager.self) var feedManager
    let list: FeedList

    @State private var isEditingList: Bool = false
    @State private var isShowingFeeds: Bool = false
    @State private var isShowingRules: Bool = false
    @State private var isShowingDeleteAlert: Bool = false

    private let iconSize: CGFloat = 64
    private let iconCornerRadius: CGFloat = 14

    @Namespace private var namespace
    @Namespace private var editNamespace
    @Namespace private var feedsNamespace
    @Namespace private var rulesNamespace

    private var iconGradient: AnyShapeStyle {
        if let icon = ListIcon(rawValue: list.icon) {
            AnyShapeStyle(icon.gradient)
        } else {
            AnyShapeStyle(Color.accentColor.gradient)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            BorderedIcon(
                systemImage: list.icon,
                background: iconGradient,
                size: iconSize,
                iconSizeFactor: 0.45,
                cornerRadius: iconCornerRadius
            )
            .padding(.bottom, 4)

            Text(list.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            actionButtons
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .sheet(isPresented: $isEditingList) {
            ListEditSheet(list: list)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
                .navigationTransition(.zoom(sourceID: list.id, in: editNamespace))
        }
        .sheet(isPresented: $isShowingFeeds) {
            ListFeedSelectionSheet(list: list)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
                .navigationTransition(.zoom(sourceID: list.id, in: feedsNamespace))
        }
        .sheet(isPresented: $isShowingRules) {
            ListRulesSheet(list: list)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
                .navigationTransition(.zoom(sourceID: list.id, in: rulesNamespace))
        }
        .alert(
            String(localized: "ListMenu.Delete.Title", table: "Lists"),
            isPresented: $isShowingDeleteAlert
        ) {
            Button(String(localized: "ListMenu.Delete.Confirm", table: "Lists"),
                   role: .destructive) {
                feedManager.deleteList(list)
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "ListMenu.Delete.Message.\(list.name)", table: "Lists"))
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        CompatibleGlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Button {
                    isShowingFeeds = true
                } label: {
                    Text(String(localized: "ListMenu.Feeds", table: "Lists"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .matchedTransitionSource(id: list.id, in: feedsNamespace)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.capsule)
                .compatibleGlassEffectID("ListFeeds", in: namespace)

                Button {
                    isShowingRules = true
                } label: {
                    Text(String(localized: "ListMenu.Rules", table: "Lists"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .matchedTransitionSource(id: list.id, in: rulesNamespace)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.capsule)
                .compatibleGlassEffectID("ListRules", in: namespace)

                Button {
                    isEditingList = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 36)
                        .matchedTransitionSource(id: list.id, in: editNamespace)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.circle)
                .accessibilityLabel(String(localized: "ListHeader.Edit", table: "Lists"))
                .compatibleGlassEffectID("ListEdit", in: namespace)

                Button(role: .destructive) {
                    isShowingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 36)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.circle)
                .tint(.red)
                .accessibilityLabel(String(localized: "ListMenu.Delete", table: "Lists"))
                .compatibleGlassEffectID("ListDelete", in: namespace)

                Spacer(minLength: 0)
            }
        }
    }
}
