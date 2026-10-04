import AppKit

/// Responder chain actions the menu bar and toolbar send without knowing which
/// window, if any, will handle them.
@objc protocol BrowserActions {
    func goBack(_ sender: Any?)
    func goForward(_ sender: Any?)
    func newBrowserWindow(_ sender: Any?)
}
