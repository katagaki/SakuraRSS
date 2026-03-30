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
        .ignoresSafeArea()
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
              let image = imageView.image,
              bounds.size != .zero,
              zoomScale == 1.0 else { return }
        let fitSize = Self.aspectFitSize(for: image.size, in: bounds.size)
        if imageView.frame.size != fitSize {
            imageView.frame = CGRect(origin: .zero, size: fitSize)
            contentSize = fitSize
        }
        // Center the image within the scroll view bounds
        let offsetX = max((bounds.width - contentSize.width) / 2, 0)
        let offsetY = max((bounds.height - contentSize.height) / 2, 0)
        imageView.frame.origin = CGPoint(x: offsetX, y: offsetY)
    }

    static func aspectFitSize(for imageSize: CGSize, in boundsSize: CGSize) -> CGSize {
        let widthRatio = boundsSize.width / imageSize.width
        let heightRatio = boundsSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
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
        if scrollView.zoomScale == 1.0 && scrollView.bounds.size != .zero {
            let fitSize = LayoutAwareScrollView.aspectFitSize(for: image.size, in: scrollView.bounds.size)
            imageView.frame = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize
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
