import SwiftUI

/// Keeps the screen awake while podcast downloads or transcriptions are active.
struct KeepScreenOnDuringPodcastWork: ViewModifier {
    @State private var manager = PodcastDownloadManager.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: manager.activeDownloads.isEmpty, initial: true) { _, isEmpty in
                UIApplication.shared.isIdleTimerDisabled = !isEmpty
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }
}

extension View {
    func keepScreenOnDuringPodcastWork() -> some View {
        modifier(KeepScreenOnDuringPodcastWork())
    }
}
