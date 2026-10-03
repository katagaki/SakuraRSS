import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension PlatformImage {

    nonisolated static func whiteSymbol(named name: String, pointSize: CGFloat) -> PlatformImage? {
        #if canImport(UIKit)
        let configuration = PlatformImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        return PlatformImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        #else
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        #endif
    }
}
