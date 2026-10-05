import AppKit

/// The field is only as tall as its text, but the capsule around it is
/// taller; this sends clicks anywhere in the capsule to the field, instead of
/// to the progress view behind it, which would take focus from the field.
final class AddressBarContentView: NSView {

    weak var field: NSTextField?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        guard let field, !hit.isDescendant(of: field) else { return hit }
        // While editing, the field editor has to take the click: handing it
        // to the field starts a new editing session, ending the current one.
        return (field.currentEditor() as? NSView) ?? field
    }
}
