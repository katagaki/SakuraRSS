import UIKit

/// Overlay window that only intercepts touches landing on the toast itself.
final class BookmarkToastWindow: UIWindow {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else { return nil }
        return hitView === rootViewController?.view ? nil : hitView
    }
}
