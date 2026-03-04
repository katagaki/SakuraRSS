import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context _: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        let safari = SFSafariViewController(url: url, configuration: config)
        return safari
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {}
}
