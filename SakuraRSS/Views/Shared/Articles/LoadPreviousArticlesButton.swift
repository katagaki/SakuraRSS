import SwiftUI

/// Sentinel pinned to the bottom of an article list. Manual mode shows a
/// tap target; auto mode fires from `.onAppear` so List's lazy rendering
/// triggers a load whenever the user scrolls the sentinel into view.
struct LoadPreviousArticlesButton: View {

    let action: () -> Void
    var articleCount: Int = 0

    @AppStorage("Articles.AutoLoadWhileScrolling") private var autoLoadWhileScrolling: Bool = false
    @State private var isLoading = false

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
        .frame(minHeight: isLoading ? 44 : 1)
        .onAppear {
            guard !isLoading else { return }
            isLoading = true
            action()
        }
        .onChange(of: articleCount) { _, _ in
            // The previous load completed; allow the next onAppear to fire.
            isLoading = false
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
