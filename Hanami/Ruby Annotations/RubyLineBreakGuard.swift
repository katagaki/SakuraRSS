import CoreText
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// TextKit 2 drops the reading when a line breaks inside a ruby base, so this
/// refuses those breaks. Text views may already use the layout manager's
/// delegate (UITextView does), so everything else is forwarded to it.
public final class RubyLineBreakGuard: NSObject, NSTextLayoutManagerDelegate {

    nonisolated(unsafe) private weak var wrappedDelegate: (any NSTextLayoutManagerDelegate)?

    public func install(on textLayoutManager: NSTextLayoutManager?) {
        guard let textLayoutManager, textLayoutManager.delegate !== self else { return }
        wrappedDelegate = textLayoutManager.delegate
        textLayoutManager.delegate = self
    }

    public nonisolated override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (wrappedDelegate?.responds(to: selector) ?? false)
    }

    public nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
        if let wrappedDelegate, wrappedDelegate.responds(to: selector) {
            return wrappedDelegate
        }
        return super.forwardingTarget(for: selector)
    }

    public func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        shouldBreakLineBefore location: any NSTextLocation,
        hyphenating: Bool
    ) -> Bool {
        guard Self.isOutsideRuby(location, in: textLayoutManager) else { return false }
        return wrappedDelegate?.textLayoutManager?(
            textLayoutManager, shouldBreakLineBefore: location, hyphenating: hyphenating
        ) ?? true
    }

    private static func isOutsideRuby(
        _ location: any NSTextLocation, in textLayoutManager: NSTextLayoutManager
    ) -> Bool {
        guard let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
              let attributedString = contentStorage.attributedString else { return true }
        let offset = contentStorage.offset(from: contentStorage.documentRange.location, to: location)
        guard offset > 0, offset < attributedString.length else { return true }
        let rubyKey = NSAttributedString.Key(kCTRubyAnnotationAttributeName as String)
        guard let annotationBefore = attributedString.attribute(rubyKey, at: offset - 1, effectiveRange: nil),
              let annotationAfter = attributedString.attribute(rubyKey, at: offset, effectiveRange: nil) else {
            return true
        }
        return (annotationBefore as AnyObject) !== (annotationAfter as AnyObject)
    }
}
