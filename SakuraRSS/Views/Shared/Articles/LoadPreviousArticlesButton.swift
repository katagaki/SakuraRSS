import SwiftUI

/// Sentinel pinned to the bottom of an article list.
/// Manual mode shows a tap-to-load button. Auto mode keeps firing `action()`
/// while the sentinel is on-screen, so it works whether the user has to scroll
/// to reveal it or whether it was visible from the start because the feed
/// didn't fill the viewport.
struct LoadPreviousArticlesButton: View {

    let action: () -> Void

    @AppStorage("Articles.AutoLoadWhileScrolling") private var autoLoadWhileScrolling: Bool = false
    @State private var isOnScreen = false

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
        .task(id: isOnScreen) {
            guard isOnScreen else { return }
            while !Task.isCancelled {
                withAnimation(.smooth.speed(2.0)) {
                    action()
                }
                try? await Task.sleep(for: .milliseconds(500))
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
