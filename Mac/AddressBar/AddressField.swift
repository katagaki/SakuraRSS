import AppKit

/// Reports gaining focus, which `NSTextField`'s delegate only hears about on
/// the first keystroke.
final class AddressField: NSTextField {

    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            onFocus?()
        }
        return didBecome
    }
}
