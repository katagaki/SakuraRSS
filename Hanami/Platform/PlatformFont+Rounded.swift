import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension PlatformFont {

    nonisolated var rounded: PlatformFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        #if canImport(UIKit)
        return PlatformFont(descriptor: descriptor, size: pointSize)
        #else
        return PlatformFont(descriptor: descriptor, size: pointSize) ?? self
        #endif
    }
}
