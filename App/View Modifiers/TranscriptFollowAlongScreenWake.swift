import SwiftUI
import UIKit

/// Releases the Follow Along screen-wake hold when the transcript is hidden,
/// the view disappears, or the app leaves the foreground.
struct TranscriptFollowAlongScreenWake: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var isKeepingScreenAwake: Bool
    let showingTranscript: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                UIApplication.shared.isIdleTimerDisabled = newPhase == .active && isKeepingScreenAwake
            }
            .onChange(of: showingTranscript) { _, isShowing in
                if !isShowing {
                    releaseScreenWake()
                }
            }
            .onDisappear(perform: releaseScreenWake)
    }

    private func releaseScreenWake() {
        isKeepingScreenAwake = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

extension View {
    func transcriptFollowAlongScreenWake(
        isKeepingScreenAwake: Binding<Bool>,
        showingTranscript: Bool
    ) -> some View {
        modifier(TranscriptFollowAlongScreenWake(
            isKeepingScreenAwake: isKeepingScreenAwake,
            showingTranscript: showingTranscript
        ))
    }
}
