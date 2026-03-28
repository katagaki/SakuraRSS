import SwiftUI

struct ImageViewerView: View {

    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                ZoomableScrollView(image: image)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sakuraBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Spacer()
            }
        }
        .task {
            image = await CachedAsyncImage<EmptyView>.loadImage(from: url)
        }
    }
}

private class LayoutAwareScrollView: UIScrollView {
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let imageView = viewWithTag(1) as? UIImageView,
              bounds.size != .zero else { return }
        if imageView.frame.size != bounds.size {
            imageView.frame = bounds
            contentSize = bounds.size
        }
    }
}

private struct ZoomableScrollView: UIViewRepresentable {

    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = LayoutAwareScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 1
        scrollView.addSubview(imageView)

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(1) as? UIImageView else { return }
        imageView.image = image
        if scrollView.bounds.size != .zero {
            imageView.frame = scrollView.bounds
            scrollView.contentSize = scrollView.bounds.size
        }
        context.coordinator.centerImageView(in: scrollView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {

        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageView(in: scrollView)
        }

        func centerImageView(in scrollView: UIScrollView) {
            guard let imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            imageView.frame = frameToCenter
        }
    }
}
