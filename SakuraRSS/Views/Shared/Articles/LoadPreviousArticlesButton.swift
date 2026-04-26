import SwiftUI

/// Sentinel pinned to the bottom of an article list. Manual mode shows a
/// tap target; auto mode fires when the scroll position approaches the
/// bottom and reveals a progress indicator until the new batch arrives.
struct LoadPreviousArticlesButton: View {

    let action: () -> Void
    var articleCount: Int = 0

    @AppStorage("Articles.AutoLoadWhileScrolling") private var autoLoadWhileScrolling: Bool = false
    @State private var isLoading: Bool = false
    @State private var isNearBottom: Bool = false
    @State private var fireToken: Int = 0

    /// Distance (in points) from the bottom at which auto-load fires.
    private static let nearBottomThreshold: CGFloat = 800

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
        .frame(minHeight: 44)
        .padding(.vertical, 4)
        .onScrollGeometryChange(for: Bool.self) { geo in
            let distance = geo.contentSize.height - geo.contentOffset.y - geo.containerSize.height
            return distance < Self.nearBottomThreshold
        } action: { _, near in
            guard near != isNearBottom else { return }
            isNearBottom = near
            fireToken &+= 1
        }
        .onChange(of: articleCount) { _, _ in
            isLoading = false
            fireToken &+= 1
        }
        .task(id: fireToken) {
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, isNearBottom, !isLoading else { return }
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
