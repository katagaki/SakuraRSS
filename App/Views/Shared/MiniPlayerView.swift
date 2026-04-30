import SwiftUI

struct MiniPlayerView: View {

    @Environment(FeedManager.self) var feedManager
    private let audioPlayer = AudioPlayer.shared
    let transitionID: String
    let transitionNamespace: Namespace.ID
    let onTap: (Article) -> Void

    var body: some View {
        if let articleID = audioPlayer.currentArticleID,
           let article = feedManager.article(byID: articleID) {
            Button {
                onTap(article)
            } label: {
                HStack(spacing: 12) {
                    artwork(for: article)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.leading, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(audioPlayer.currentEpisodeTitle ?? article.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        if let feedTitle = audioPlayer.currentFeedTitle {
                            Text(feedTitle)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        audioPlayer.togglePlayPause()
                    } label: {
                        Image(systemName: audioPlayer.isPlaying
                              ? "pause.fill"
                              : "play.fill")
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        audioPlayer.stop()
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
    private func artwork(for article: Article) -> some View {
        if let imageURL = article.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.secondary.opacity(0.15))
            }
            .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
