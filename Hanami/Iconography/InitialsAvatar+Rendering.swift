import CoreGraphics
import CoreText
import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension InitialsAvatar {

    private nonisolated static let renderScale: CGFloat = 2

    nonisolated static func renderToImage(name: String, size: CGFloat = 128) -> PlatformImage? {
        let pixelSize = Int(size * renderScale)
        guard pixelSize > 0, let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: renderScale, y: renderScale)
        let bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        fillBackground(in: context, bounds: bounds, name: name)

        if isGlyphBased(name) {
            drawSymbol(in: context, bounds: bounds, size: size)
        } else {
            drawInitials(in: context, bounds: bounds, size: size, name: name)
        }

        guard let cgImage = context.makeImage() else { return nil }
        return PlatformImage(cgImage: cgImage, scale: renderScale, orientation: .up)
    }

    private nonisolated static func fillBackground(in context: CGContext, bounds: CGRect, name: String) {
        let background = PlatformColor(
            hue: backgroundHue(for: name), saturation: 0.45, brightness: 0.75, alpha: 1.0
        )
        let path = CGPath(
            roundedRect: bounds,
            cornerWidth: bounds.width / 8,
            cornerHeight: bounds.height / 8,
            transform: nil
        )
        context.setFillColor(background.cgColor)
        context.addPath(path)
        context.fillPath()
    }

    private nonisolated static func drawSymbol(in context: CGContext, bounds: CGRect, size: CGFloat) {
        guard let symbol = PlatformImage.whiteSymbol(named: "newspaper", pointSize: size * 0.4),
              let symbolImage = symbol.cgImage else { return }
        let symbolRect = CGRect(
            x: (size - symbol.size.width) / 2,
            y: (size - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        // CGContext draws images bottom-up, and the glyph is not vertically symmetric.
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(symbolImage, in: CGRect(
            x: symbolRect.minX,
            y: bounds.height - symbolRect.maxY,
            width: symbolRect.width,
            height: symbolRect.height
        ))
        context.restoreGState()
    }

    private nonisolated static func drawInitials(
        in context: CGContext, bounds: CGRect, size: CGFloat, name: String
    ) {
        let font = PlatformFont.systemFont(ofSize: size * 0.4, weight: .semibold).rounded
        let attributed = NSAttributedString(string: initials(for: name), attributes: [
            .font: font,
            .foregroundColor: PlatformColor.white
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        context.textPosition = CGPoint(
            x: (bounds.width - textBounds.width) / 2 - textBounds.minX,
            y: (bounds.height - textBounds.height) / 2 - textBounds.minY
        )
        CTLineDraw(line, context)
    }
}
