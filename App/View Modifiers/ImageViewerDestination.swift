import SwiftUI

struct ImageViewerDestination: ViewModifier {

    @Binding var imageURL: URL?
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $imageURL) { url in
                ImageViewerView(url: url)
                    .navigationTransition(.zoom(sourceID: url, in: namespace))
            }
            .browserOverlayPage(item: $imageURL) { url in
                BrowserPageIdentity(
                    title: String(localized: "Overlay.Image", table: "Browser"),
                    subtitle: url.host,
                    symbolName: "photo"
                )
            }
    }
}

extension View {
    func imageViewerDestination(item imageURL: Binding<URL?>, in namespace: Namespace.ID) -> some View {
        modifier(ImageViewerDestination(imageURL: imageURL, namespace: namespace))
    }
}
