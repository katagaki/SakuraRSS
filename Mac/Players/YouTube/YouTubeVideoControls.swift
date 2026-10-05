import SwiftUI
import WebKit

struct YouTubeVideoControls: View {

    let session: YouTubePlayerSession
    let isPlaying: Bool
    let webView: WKWebView?
    let chapters: [YouTubeChapter]
    let videoURL: URL?

    var body: some View {
        HStack(spacing: 16) {
            Button { seek(by: -10) } label: { Image(systemName: "gobackward.10") }
            Button { session.togglePlayPause() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 20)
            }
            Button { seek(by: 10) } label: { Image(systemName: "goforward.10") }
            YouTubeScrubber(session: session) { time in
                YouTubePlaybackCommands.seek(webView, to: time)
            }
            if !chapters.isEmpty {
                chapterMenu
            }
            Button { YouTubePlaybackCommands.togglePictureInPicture(webView) } label: {
                Image(systemName: "pip.enter")
            }
            Button { YouTubePlaybackCommands.enterFullscreen(webView) } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            if let videoURL {
                Button { NSWorkspace.shared.open(videoURL) } label: { Image(systemName: "safari") }
                    .help(String(localized: "YouTube.OpenInBrowser", table: "Integrations"))
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 15, weight: .medium))
        .disabled(webView == nil)
    }

    private var chapterMenu: some View {
        Menu {
            ForEach(chapters) { chapter in
                Button("\(chapter.formattedTimestamp)  \(chapter.title)") {
                    YouTubePlaybackCommands.seek(webView, to: chapter.startTime)
                }
            }
        } label: {
            Image(systemName: "list.bullet")
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(String(localized: "YouTube.Chapters", table: "Integrations"))
    }

    private func seek(by offset: TimeInterval) {
        let target = min(max(session.currentTime + offset, 0), max(session.duration, 0))
        YouTubePlaybackCommands.seek(webView, to: target)
    }
}
