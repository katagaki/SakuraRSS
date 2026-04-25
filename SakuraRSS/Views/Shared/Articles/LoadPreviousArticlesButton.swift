import SwiftUI

/// Sentinel pinned to the bottom of an article list.
/// Manual mode shows a tap-to-load button. Auto mode triggers `action()` once
/// each time the sentinel scrolls into view, so subsequent scrolls past the
/// next batch re-fire the next load.
struct LoadPreviousArticlesButton: View {

    let action: () -> Void

    @AppStorage("Articles.AutoLoadWhileScrolling") private var autoLoadWhileScrolling: Bool = false

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
        .onScrollVisibilityChange(threshold: 0.1) { visible in
            guard visible else { return }
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
