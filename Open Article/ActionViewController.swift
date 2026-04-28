import SwiftUI

class ActionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(
            rootView: OpenArticleExtensionView(extensionContext: extensionContext) { [weak self] url in
                self?.openURLInHostApp(url)
            }
        )
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    /// Walks the responder chain to find a `UIApplication` and asks it to open
    /// the URL. Action extensions can't access `UIApplication.shared` directly.
    private func openURLInHostApp(_ url: URL) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
                return
            }
            responder = current.next
        }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
