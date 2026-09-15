import SwiftUI
import Hanami

/// The tab's last snapshot, or — for a tab that has not been left yet, so has
/// none — the app's own mark.
struct BrowserTabPreview: View {

    @Environment(BrowserTabStore.self) private var store
    let tab: BrowserTab

    var body: some View {
        if let snapshot = store.snapshots[tab.id] {
            // Matched to the card's width with the overflow falling off the
            // bottom. Filling would scale by height instead and crop the sides,
            // because cropping the navigation bar leaves the snapshot shorter
            // in ratio than the screen.
            GeometryReader { proxy in
                Image(uiImage: snapshot)
                    .resizable()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.width / snapshotAspectRatio(snapshot)
                    )
            }
        } else {
            standIn
        }
    }

    private func snapshotAspectRatio(_ snapshot: UIImage) -> CGFloat {
        guard snapshot.size.height > 0 else { return 1 }
        return snapshot.size.width / snapshot.size.height
    }

    private var standIn: some View {
        Image("SakuraIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 56)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
