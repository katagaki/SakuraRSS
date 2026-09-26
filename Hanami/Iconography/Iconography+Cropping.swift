import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension PlatformImage {

    /// Returns a copy cropped to the largest centered square. No-op if already square.
    nonisolated func centerSquareCropped() -> PlatformImage {
        guard let cgImage else { return self }
        let width = cgImage.width
        let height = cgImage.height
        guard width != height else { return self }
        let side = min(width, height)
        let originX = (width - side) / 2
        let originY = (height - side) / 2
        let rect = CGRect(x: originX, y: originY, width: side, height: side)
        guard let cropped = cgImage.cropping(to: rect) else { return self }
        return PlatformImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
