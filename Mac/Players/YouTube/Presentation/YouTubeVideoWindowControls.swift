import Hanami
import SwiftUI

/// Covers the detached video so the page never takes the mouse: a click
/// plays or pauses, and hovering shows the window's Liquid Glass buttons.
struct YouTubeVideoWindowControls: View {

    let session: YouTubePlayerSession
    let mode: YouTubeVideoPresenter.Mode
    let onReturn: () -> Void
    let onClose: () -> Void
    @State private var isHovering = false

    var body: some View {
        surface
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

    @ViewBuilder
    private var surface: some View {
        let tappable = Color.clear
            .contentShape(.rect)
            .onTapGesture { session.togglePlayPause() }
        if mode == .pictureInPicture {
            tappable.gesture(WindowDragGesture())
        } else {
            tappable
        }
    }

    private var buttons: some View {
        GlassEffectContainer {
            VStack {
                HStack {
                    if mode == .pictureInPicture {
                        Button(action: onClose) { Image(systemName: "xmark") }
                        Spacer()
                        Button(action: onReturn) { Image(systemName: "pip.exit") }
                            .help(String(localized: "Player.ShowVideo", table: "Mac"))
                    } else {
                        Button(action: onReturn) { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                        Spacer()
                    }
                }
                Spacer()
                Button { session.togglePlayPause() } label: {
                    Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .frame(width: 32, height: 32)
                }
                Spacer()
            }
            .padding(mode == .pictureInPicture ? 10 : 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .font(.system(size: 13, weight: .semibold))
    }
}
