import SwiftUI

/// `AsyncImage`, loading through `CachedImageData` so cached images show without a fetch.
/// `content` has to draw something in every phase: a task on an empty view never starts.
struct CachedImage<Content: View>: View {

    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    @State private var phase = AsyncImagePhase.empty

    var body: some View {
        content(phase)
            .task(id: url) {
                phase = .empty
                guard let url else { return }
                guard let data = await CachedImageData.load(url), let image = NSImage(data: data) else {
                    phase = .failure(URLError(.cannotDecodeContentData))
                    return
                }
                phase = .success(Image(nsImage: image))
            }
    }
}
