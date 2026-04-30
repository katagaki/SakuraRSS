import Foundation

extension YouTubePlayerView {

    /// Fetches the public YouTube oEmbed JSON for ephemeral articles so the
    /// video title and channel name show up without needing a feed entry.
    func fetchYouTubeOEmbed() async {
        guard let escaped = article.url.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ),
              let endpoint = URL(
                string: "https://www.youtube.com/oembed?url=\(escaped)&format=json"
              ) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(
                from: endpoint
            )
            guard let json = try JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any] else { return }
            if let title = json["title"] as? String, !title.isEmpty {
                fetchedTitle = title
                session.videoTitle = title
            }
            if let author = json["author_name"] as? String, !author.isEmpty {
                fetchedAuthor = author
                session.channelTitle = author
            }
        } catch {}
    }
}
