import SwiftUI

/// Sentinel at the end of an article list. Manual mode shows a button;
/// auto mode loads via `.onAppear` from List's lazy rendering.
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
            isLoading = false
        }
    }

    /// No `withAnimation`; preserves the list's current scroll offset.
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
