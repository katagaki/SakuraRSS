import SwiftUI
import Hanami

struct IconImage: View {

    let image: UIImage
    let size: CGFloat
    let cornerRadius: CGFloat
    let isCircle: Bool
    let skipInset: Bool

    var isNonSquare: Bool { !image.isSquare }
    var isFilledSquare: Bool { image.isFilledSquare }
    var showInset: Bool { !skipInset && isCircle && !image.isCircular && image.hasTransparentPixels }
    var needsWhiteBackground: Bool { !skipInset && image.isDark && image.hasTransparentPixels }
    var isNearBlack: Bool { image.isNearBlack && image.hasTransparentPixels }
    var showRoundRectInset: Bool { !skipInset && !isCircle && image.isSquare && image.hasTransparentPixels }

    var iconSize: CGFloat {
        if skipInset {
            return size
        } else if isNearBlack {
            return size * 0.7
        } else if isNonSquare {
            let padding: CGFloat = isCircle ? 3 : 2
            return size - padding * 2
        } else if showInset || needsWhiteBackground || showRoundRectInset {
            return size * 0.7
        } else {
            return size
        }
    }

    init(_ image: UIImage, size: CGFloat = 20, cornerRadius: CGFloat = 3,
         circle: Bool = false, skipInset: Bool = false) {
        self.image = image
        self.size = size
        self.cornerRadius = cornerRadius
        self.isCircle = circle
        self.skipInset = skipInset
    }

    var body: some View {
        let baseImage = Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: isNonSquare ? .fit : .fill)
            .frame(width: iconSize, height: iconSize)
            .frame(width: size, height: size)
            .background(image.nearWhiteAverageGradient)

        if isCircle {
            baseImage
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
                }
        } else {
            baseImage
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
                }
        }
    }
}
