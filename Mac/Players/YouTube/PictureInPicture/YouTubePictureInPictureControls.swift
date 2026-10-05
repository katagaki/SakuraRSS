import Hanami
import SwiftUI

/// Covers the floating video so the page never takes the mouse: a click
/// plays or pauses, a drag moves the panel, and hovering shows Liquid Glass
/// controls.
struct YouTubePictureInPictureControls: View {

    let session: YouTubePlayerSession
    let onDragChanged: () -> Void
    let onDragEnded: () -> Void
    let onReturn: () -> Void
    let onClose: () -> Void
    @State private var isHovering = false

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture { session.togglePlayPause() }
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { _ in onDragChanged() }
                    .onEnded { _ in onDragEnded() }
            )
            .overlay {
                if isHovering {
                    controls
                        .transition(.opacity)
                }
            }
            .onHover { hovering in
                withAnimation(.smooth(duration: 0.2)) { isHovering = hovering }
            }
            .onChange(of: session.currentArticle == nil) { _, hasStopped in
                if hasStopped { onClose() }
            }
            // The panel's hidden title bar would otherwise inset the controls.
            .ignoresSafeArea()
    }

    private var controls: some View {
        GlassEffectContainer {
            VStack {
                HStack {
                    Button(action: onClose) { symbol("xmark", size: 15) }
                    Spacer()
                    Button(action: onReturn) { symbol("pip.exit", size: 15) }
                        .help(String(localized: "Player.ShowVideo", table: "Mac"))
                }
                Spacer()
                HStack(spacing: 18) {
                    Button { YouTubePlaybackCommands.seek(session.webView, by: -10) } label: {
                        symbol("gobackward.10", size: 20)
                    }
                    Button { session.togglePlayPause() } label: {
                        symbol(session.isPlaying ? "pause.fill" : "play.fill", size: 30)
                    }
                    Button { YouTubePlaybackCommands.seek(session.webView, by: 10) } label: {
                        symbol("goforward.10", size: 20)
                    }
                }
                Spacer()
            }
            .padding(12)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
        .background(Color.black.opacity(0.2).allowsHitTesting(false))
    }

    private func symbol(_ name: String, size: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .frame(width: size * 1.4, height: size * 1.4)
    }
}
