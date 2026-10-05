import AppKit

/// The content list's table, which also takes single-key reading shortcuts
/// when no modifier is held.
final class ContentListTableView: NSTableView {

    enum Shortcut {
        case next, previous, toggleRead, toggleBookmark, openInBrowser, open
    }

    var onShortcut: ((Shortcut) -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.subtracting([.numericPad, .function]).isEmpty,
              let shortcut = shortcut(for: event) else {
            super.keyDown(with: event)
            return
        }
        onShortcut?(shortcut)
    }

    private func shortcut(for event: NSEvent) -> Shortcut? {
        if event.keyCode == 36 || event.keyCode == 76 {
            return .open
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "j": return .next
        case "k": return .previous
        case "m": return .toggleRead
        case "s": return .toggleBookmark
        case "o": return .openInBrowser
        default: return nil
        }
    }
}
