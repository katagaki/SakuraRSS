import SwiftUI

extension YouTubePlayerView {

    @ViewBuilder
    var playerVideoArea: some View {
        YouTubePlayerWebView(
            urlString: article.url,
            isPlaying: $isPlaying,
            webView: $webView,
            isAd: $isAd,
            isAdSkippable: $isAdSkippable,
            advertiserURL: $advertiserURL,
            videoAspectRatio: $videoAspectRatio,
            isPiP: $isPiP,
            chapters: $chapters,
            onTimeUpdate: { newTime in
                YouTubePlayerSession.shared.currentTime = newTime
            },
            onDurationUpdate: { newDuration in
                YouTubePlayerSession.shared.duration = newDuration
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
        .animation(.smooth.speed(2.0), value: isAd && !isPiP && hasStartedPlaying)
    }
}
