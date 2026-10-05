import AppKit

/// Ends editing on a click anywhere outside the field and its suggestions, or
/// when the window stops being key. Clicks on views that don't take focus,
/// like the page or the window's background, wouldn't otherwise end it.
extension AddressBarController {

    func startWatchingForDismissal() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.dismissIfOutside(event)
            return event
        }
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: field.window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.field.window?.makeFirstResponder(nil)
            }
        }
    }

    func stopWatchingForDismissal() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        resignKeyObserver = nil
    }

    private func dismissIfOutside(_ event: NSEvent) {
        guard !suggestionsPanel.owns(event.window) else { return }
        if event.window === field.window {
            let location = containerView.convert(event.locationInWindow, from: nil)
            guard !containerView.bounds.contains(location) else { return }
        }
        field.window?.makeFirstResponder(nil)
    }
}
