import UIKit

enum RedditHelper {

    static var isAppInstalled: Bool {
        guard let url = URL(string: "reddit://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

enum XHelper {

    static var isAppInstalled: Bool {
        guard let url = URL(string: "twitter://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

enum InstagramHelper {

    static var isAppInstalled: Bool {
        guard let url = URL(string: "instagram://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

enum YouTubeHelper {

    static var isAppInstalled: Bool {
        guard let url = URL(string: "youtube://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Attempts to open a YouTube URL in the YouTube app.
    /// Falls back to the system URL handler if the app is not installed.
    static func openInApp(url urlString: String) {
        guard let url = URL(string: urlString) else { return }

        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.scheme = "youtube"
            if let youtubeURL = components.url,
               UIApplication.shared.canOpenURL(youtubeURL) {
                UIApplication.shared.open(youtubeURL)
                return
            }
        }

        UIApplication.shared.open(url)
    }
}
