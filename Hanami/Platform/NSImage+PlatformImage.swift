#if !canImport(UIKit)
import AppKit
import CoreGraphics
import Foundation

/// AppKit bakes orientation into the bitmap, so there is nothing to carry the
/// way `UIImage.Orientation` does. The case exists only so call sites that
/// round-trip an orientation keep compiling.
public enum PlatformImageBakedOrientation: Sendable {
    // swiftlint:disable:next identifier_name
    case up
}

public extension NSImage {

    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    convenience init(cgImage: CGImage, scale: CGFloat, orientation: PlatformImageBakedOrientation) {
        let divisor = scale > 0 ? scale : 1
        self.init(
            cgImage: cgImage,
            size: NSSize(width: CGFloat(cgImage.width) / divisor, height: CGFloat(cgImage.height) / divisor)
        )
    }

    var cgImage: CGImage? {
        var rect = NSRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// Pixels per point, recovered from the backing bitmap the way `UIImage.scale`
    /// reports it. Falls back to 1 for vector or empty images.
    var scale: CGFloat {
        guard size.width > 0, let cgImage else { return 1 }
        return CGFloat(cgImage.width) / size.width
    }

    var imageOrientation: PlatformImageBakedOrientation { .up }

    func pngData() -> Data? {
        bitmapRepresentation?.representation(using: .png, properties: [:])
    }

    func jpegData(compressionQuality: CGFloat) -> Data? {
        bitmapRepresentation?.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }

    private var bitmapRepresentation: NSBitmapImageRep? {
        guard let cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage)
    }
}
#endif
