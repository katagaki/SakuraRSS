import SwiftUI
import Hanami

extension YouTubePlayerView {

    @ViewBuilder
    var playerVideoArea: some View {
        YouTubePlayerWebView(
            urlString: article.url,
            session: session,
            isPlaying: $isPlaying,
            webView: $webView,
            isAd: $isAd,
            isAdSkippable: $isAdSkippable,
            advertiserURL: $advertiserURL,
            videoAspectRatio: $videoAspectRatio,
            isPiP: $isPiP,
            chapters: $chapters,
            onTimeUpdate: { [session] newTime in
                session.currentTime = newTime
            },
            onDurationUpdate: { [session] newDuration in
                session.duration = newDuration
            }
        )
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .clipped()
        .overlay(alignment: .top) {
            if let skippedSegmentMessage {
                Text(skippedSegmentMessage)
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth.speed(2.0), value: skippedSegmentMessage)
        .animation(.smooth.speed(2.0), value: isAd && isAdSkippable && !isPiP)
        .overlay {
            if isPiP {
                Color.black
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "pip")
                                .font(.largeTitle)
                            Text(String(localized: "YouTube.PiP.Active", table: "Integrations"))
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
            } else if !hasStartedPlaying {
                Color.black
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isAd && !isPiP && hasStartedPlaying {
                Text(String(localized: "YouTube.Ad.Label", table: "Integrations"))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .compatibleGlassEffect(in: .capsule)
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .overlay {
            if !isPiP && hasStartedPlaying {
                YouTubePlayerOverlayControls(
                    session: session,
                    isPlaying: isPlaying,
                    isAd: isAd,
                    videoAspectRatio: videoAspectRatio,
                    segments: sponsorSegments.map { (start: $0.startTime, end: $0.endTime) },
                    onTogglePiP: togglePiP,
                    onRewind: rewind,
                    onTogglePlayPause: togglePlayPause,
                    onFastForward: fastForward,
                    onSeek: { seek(to: $0) },
                    onEnterFullscreen: enterFullscreen
                )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isAd && isAdSkippable && !isPiP && hasStartedPlaying {
                Button {
                    skipAd()
                } label: {
                    Label(
                        String(localized: "YouTube.Ad.Skip", table: "Integrations"),
                        systemImage: "forward.end.fill"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .compatibleGlassEffect(in: .capsule, interactive: true, clear: true)
                .padding(.trailing, 16)
                .padding(.bottom, 64)
                .transition(.opacity)
            }
        }
        .animation(.smooth.speed(2.0), value: isAd && !isPiP && hasStartedPlaying)
        .animation(.smooth.speed(2.0), value: isAd && isAdSkippable && !isPiP && hasStartedPlaying)
    }
}
