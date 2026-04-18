import SwiftUI

/// Keeps the device screen awake while any podcast download or transcription
/// is in progress, so long-running work isn't interrupted when the device
/// would otherwise auto-lock.
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
