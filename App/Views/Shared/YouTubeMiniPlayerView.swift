import SwiftUI

struct YouTubeMiniPlayerView: View {

    let session = YouTubePlayerSession.shared
    let transitionID: String
    let transitionNamespace: Namespace.ID
    let onTap: (Article) -> Void

    var body: some View {
        if let article = session.currentArticle {
            Button {
                onTap(article)
            } label: {
                HStack(spacing: 12) {
                    artwork
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.leading, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.videoTitle ?? article.title)
                            .font(.subheadline)
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
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        session.clear()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
                .matchedTransitionSource(id: transitionID, in: transitionNamespace)
            }
            .buttonStyle(.plain)
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
                .fill(.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
