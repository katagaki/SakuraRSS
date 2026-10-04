import Hanami
import SwiftUI

/// Covers the floating video so the page never takes the mouse: a click
/// plays or pauses, a drag moves the window, and hovering shows its buttons.
struct YouTubePictureInPictureControls: View {

    let session: YouTubePlayerSession
    let onReturn: () -> Void
    let onClose: () -> Void
    @State private var isHovering = false

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture { session.togglePlayPause() }
            .gesture(WindowDragGesture())
            .overlay {
                if isHovering {
                    buttons
                        .transition(.opacity)
                }
            }
            .onHover { hovering in
                withAnimation(.smooth(duration: 0.2)) { isHovering = hovering }
            }
    }

    private var buttons: some View {
        GlassEffectContainer {
            VStack {
                HStack {
                    Button(action: onClose) { Image(systemName: "xmark") }
                    Spacer()
                    Button(action: onReturn) { Image(systemName: "pip.exit") }
                        .help(String(localized: "Player.ShowVideo", table: "Mac"))
                }
                Spacer()
                Button { session.togglePlayPause() } label: {
                    Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .frame(width: 32, height: 32)
                }
                Spacer()
            }
            .padding(10)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .font(.system(size: 13, weight: .semibold))
    }
}
