import SwiftUI

/// Visual content of the YouTube mini player bar; the surrounding `Button`
/// (which presents the full sheet) is provided by `MiniPlayerAccessoryModifier`
/// so the matched zoom transition source can be applied directly to this view.
struct YouTubeMiniPlayerBar: View {

    let session = YouTubePlayerSession.shared

    var body: some View {
        if let article = session.currentArticle {
            HStack(spacing: 12) {
                artwork
                    .frame(width: 56, height: 32)
                    .clipShape(.rect(cornerRadius: 6))
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.videoTitle ?? article.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if let channel = session.channelTitle {
                        Text(channel)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    session.togglePlayPause()
                } label: {
                    Image(systemName: session.isPlaying
                          ? "pause.fill"
                          : "play.fill")
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Button {
                    session.clear()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let url = session.artworkURL {
            CachedAsyncImage(url: url) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.secondary.opacity(0.15))
            }
            .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.5))
                .overlay {
                    Image(systemName: "play.fill")
                }
        }
    }
}
