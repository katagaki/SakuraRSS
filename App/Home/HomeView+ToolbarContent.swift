import SwiftUI
import Hanami

extension HomeView {

    @ToolbarContentBuilder
    var redesignToolbarItems: some ToolbarContent {
        if tabItems.count > 1 {
            ToolbarItem(id: "home.sectionBar", placement: .principal) {
                HomeSectionBar(
                    tabs: tabItems,
                    selectionStore: selectionStore
                )
                .frame(maxWidth: .infinity)
            }
        }
        ToolbarItem(id: "home.trailing", placement: .topBarTrailing) {
            HomeTrailingControl(
                selectionStore: selectionStore,
                usesPhoneTopBarRedesign: true,
                showingWeatherLocationPicker: $showingWeatherLocationPicker,
                sectionDisplayMenu: sectionDisplayMenu
            )
        }
        .sharedBackgroundVisibility(.automatic)
    }

    @ToolbarContentBuilder
    var nonRedesignToolbarItems: some ToolbarContent {
        ToolbarItem(id: "home.principalLabel", placement: .principal) {
            principalToolbarLabel
        }
        if isTodaySelected {
            ToolbarItem(id: "home.trailing", placement: .topBarTrailing) {
                HomeTrailingControl(
                    selectionStore: selectionStore,
                    usesPhoneTopBarRedesign: false,
                    showingWeatherLocationPicker: $showingWeatherLocationPicker,
                    sectionDisplayMenu: sectionDisplayMenu
                )
            }
            .sharedBackgroundVisibility(.hidden)
        }
        if markAllReadPosition == .top, !isTodaySelected {
            ToolbarItemGroup(placement: .topBarLeading) {
                markAllReadButton
            }
        }
        if homeRefreshState.hasActiveProgress {
            #if !os(visionOS)
            ToolbarSpacer(.fixed, placement: .topBarLeading)
            #endif
            ToolbarItemGroup(placement: .topBarLeading) {
                FeedRefreshProgressDonut(
                    progress: homeRefreshState.progress,
                    isStopping: homeRefreshState.isStopping,
                    onStop: cancelHomeRefresh
                )
            }
        }
    }

    private var markAllReadButton: some View {
        Button {
            isShowingMarkAllReadConfirmation = true
        } label: {
            Image(systemName: "envelope.open")
                .font(.system(size: 14.0))
        }
        #if targetEnvironment(macCatalyst)
        .alert(
            String(localized: "MarkAllRead.Confirm", table: "Articles"),
            isPresented: $isShowingMarkAllReadConfirmation
        ) {
            Button(String(localized: "MarkAllRead", table: "Articles")) {
                Task { @MainActor in performMarkAllRead() }
            }
            Button(role: .cancel) {}
        }
        #else
        .popover(isPresented: $isShowingMarkAllReadConfirmation) {
            VStack(spacing: 12) {
                Text(String(localized: "MarkAllRead.Confirm", table: "Articles"))
                    .font(.body)
                Button {
                    isShowingMarkAllReadConfirmation = false
                    Task { @MainActor in performMarkAllRead() }
                } label: {
                    Text(String(localized: "MarkAllRead", table: "Articles"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .presentationCompactAdaptation(.popover)
        }
        #endif
    }
}
