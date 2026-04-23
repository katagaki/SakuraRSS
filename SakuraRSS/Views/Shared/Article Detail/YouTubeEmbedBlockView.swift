import SwiftUI
import WebKit

/// Inline YouTube embed for `{{YOUTUBE}}` markers with a compact control row.
struct YouTubeEmbedBlockView: View {

    let videoID: String

    @Environment(\.openURL) private var openURL
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var webView: WKWebView?
    @State private var isAd = false
    @State private var advertiserURL: URL?
    @State private var videoAspectRatio: CGFloat = 16 / 9
    @State private var isPiP = false
    @State private var hasStartedPlaying = false
    @State private var showFullPlayer = false

    private var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(videoID)")
    }

    private var embedURL: String {
        "https://www.youtube.com/watch?v=\(videoID)"
    }

    var body: some View {
        VStack(spacing: 0) {
            YouTubePlayerWebView(
                urlString: embedURL,
                autoplay: false,
                isPlaying: $isPlaying,
                currentTime: $currentTime,
                duration: $duration,
                webView: $webView,
                isAd: $isAd,
                advertiserURL: $advertiserURL,
                videoAspectRatio: $videoAspectRatio,
                isPiP: $isPiP
            )
            .aspectRatio(videoAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay {
                if !hasStartedPlaying {
                    Color.black
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }

            controls
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.thinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: duration) { _, newDuration in
            if newDuration > 0 && !hasStartedPlaying {
                withAnimation(.smooth.speed(2.0)) {
                    hasStartedPlaying = true
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.callout)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(isAd)

            Button {
                seek(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .disabled(isAd)

            Button {
                seek(by: 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .disabled(isAd)

            Text(timeLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let watchURL {
                Button {
                    openURL(watchURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(
                    String(localized: "Article.Embed.OpenInYouTube", table: "Articles")
                ))
            }
        }
        .foregroundStyle(.primary)
    }

    private var timeLabel: String {
        let current = Int(max(0, currentTime))
        let total = Int(max(0, duration))
        return "\(formatTime(current)) / \(formatTime(total))"
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    private func togglePlayPause() {
        let script = """
        (function() {
            var v = document.querySelector('video');
            if (!v) return;
            if (v.paused) {
                window.__ytAutoplayBlocked = false;
                window.__ytUserPaused = false;
                v.play();
            } else {
                window.__ytUserPaused = true;
                v.pause();
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func seek(by delta: TimeInterval) {
        let target = max(0, currentTime + delta)
        let script = """
        (function() {
            var v = document.querySelector('video');
            if (!v) return;
            v.currentTime = \(target);
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}
