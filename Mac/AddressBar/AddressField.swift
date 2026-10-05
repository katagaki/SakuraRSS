import AppKit

/// Reports gaining focus, which `NSTextField`'s delegate only hears about on
/// the first keystroke.
final class AddressField: NSTextField {

    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            // Deferred until AppKit has installed the field editor; changing the
            // text before then hands focus straight back to the window.
            DispatchQueue.main.async { [weak self] in
                self?.onFocus?()
            }
        }
        return didBecome
    }
}
