import SwiftUI

/// Sentinel pinned to the bottom of an article list.
/// Manual mode shows a tap-to-load button. Auto mode fires `action()` once
/// when the sentinel becomes visible, and re-fires only after `articleCount`
/// changes — so a feed whose loaded chunks contain no new visible articles
/// can't get stuck spinning indefinitely.
struct LoadPreviousArticlesButton: View {

    let action: () -> Void
    var articleCount: Int = 0

    @AppStorage("Articles.AutoLoadWhileScrolling") private var autoLoadWhileScrolling: Bool = false
    @State private var isOnScreen = false
    @State private var lastFiredAtCount: Int? = nil

    var body: some View {
        Group {
            if autoLoadWhileScrolling {
                autoLoadingIndicator
            } else {
                manualButton
            }
        }
    }

    private var autoLoadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(String(localized: "LoadPrevious.Loading", table: "Articles"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .onScrollVisibilityChange(threshold: 0.05) { visible in
            isOnScreen = visible
        }
        .task(id: AutoLoadKey(isOnScreen: isOnScreen, count: articleCount)) {
            guard isOnScreen,
                  lastFiredAtCount != articleCount else { return }
            lastFiredAtCount = articleCount
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth.speed(2.0)) {
                action()
            }
        }
    }

    private var manualButton: some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                action()
            }
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
