import SwiftUI

/// Sentinel pinned to the bottom of an article list. Manual mode shows a
/// tap target; auto mode fires when the user scrolls within range of the
/// bottom and reveals a progress indicator until the new batch arrives.
struct LoadPreviousArticlesButton: View {

    let action: () -> Void
    var articleCount: Int = 0

    @AppStorage("Articles.AutoLoadWhileScrolling") private var autoLoadWhileScrolling: Bool = false
    @State private var isOnScreen = false
    @State private var isLoading = false
    @State private var lastFiredAtCount: Int? = nil

    var body: some View {
        Group {
            if articleCount > 0 {
                if autoLoadWhileScrolling {
                    autoLoadingIndicator
                } else {
                    manualButton
                }
            }
        }
    }

    /// Fires when the sentinel becomes visible. The trigger row is sized
    /// taller than the indicator content so it crosses into view a bit
    /// before the user reaches the absolute bottom of the list, but small
    /// enough that the empty placeholder isn't a distracting gap.
    private var autoLoadingIndicator: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                Text(String(localized: "LoadPrevious.Loading", table: "Articles"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 88)
        .padding(.vertical, 4)
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .onScrollVisibilityChange(threshold: 0.05) { visible in
            isOnScreen = visible
        }
        .task(id: AutoLoadKey(isOnScreen: isOnScreen, count: articleCount)) {
            isLoading = false
            guard isOnScreen, lastFiredAtCount != articleCount else { return }
            lastFiredAtCount = articleCount
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            isLoading = true
            action()
        }
    }

    /// Fires synchronously without `withAnimation` so the list keeps its
    /// existing scroll position instead of animating new rows in.
    private var manualButton: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text(String(localized: "LoadPrevious", table: "Articles"))
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }
}

private struct AutoLoadKey: Equatable {
    let isOnScreen: Bool
    let count: Int
}
