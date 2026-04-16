import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {

    let url: URL
    var entersReaderIfAvailable = false

    func makeUIViewController(context _: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = entersReaderIfAvailable
        let safari = SFSafariViewController(url: url, configuration: config)
        return safari
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {}
}
