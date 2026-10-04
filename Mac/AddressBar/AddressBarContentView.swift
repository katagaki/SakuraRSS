import AppKit

/// The field is only as tall as its text, but the capsule around it is
/// taller; this sends clicks anywhere in the capsule to the field, instead of
/// to the progress view behind it, which would take focus from the field.
final class AddressBarContentView: NSView {

    weak var field: NSTextField?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        guard let field else { return hit }
        return hit.isDescendant(of: field) ? hit : field
    }
}
