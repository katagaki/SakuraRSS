import AppKit

/// Floats the video above every Space, and when it's dropped or resized,
/// glides it against the nearest side of the screen: into a corner near the
/// top or bottom, or wherever it was let go along the side in between.
final class YouTubePictureInPicturePanel: NSPanel, NSWindowDelegate {

    private static let screenMargin: CGFloat = 16
    private static let longestSide: CGFloat = 400
    private static let shortestSide: CGFloat = 135
    private static let throwProjection: TimeInterval = 0.2
    private static let maximumThrowSpeed: CGFloat = 6000

    private var dragStart: (mouseLocation: NSPoint, origin: NSPoint)?
    private var dragSamples: [(location: NSPoint, time: TimeInterval)] = []
    private var screenObserver: NSObjectProtocol?

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.longestSide, height: Self.longestSide * 9 / 16),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        // Dragging is done by the controls, so the panel can snap on release.
        isMovable = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .black
        delegate = self
        self.contentView = contentView
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.snapToEdge(animated: false)
            }
        }
    }

    func present(aspectRatio: CGFloat) {
        let ratio = max(aspectRatio, 0.3)
        contentAspectRatio = NSSize(width: ratio, height: 1)
        contentMinSize = ratio >= 1
            ? NSSize(width: Self.shortestSide * ratio, height: Self.shortestSide)
            : NSSize(width: Self.shortestSide, height: Self.shortestSide / ratio)
        let size = ratio >= 1
            ? NSSize(width: Self.longestSide, height: Self.longestSide / ratio)
            : NSSize(width: Self.longestSide * ratio, height: Self.longestSide)
        setContentSize(size)
        if !isVisible, let visibleFrame = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame {
            setFrameOrigin(NSPoint(
                x: visibleFrame.maxX - frame.width - Self.screenMargin,
                y: visibleFrame.minY + Self.screenMargin
            ))
        }
        snapToEdge(animated: false)
        orderFrontRegardless()
    }

    func continueDrag() {
        let mouseLocation = NSEvent.mouseLocation
        let start = dragStart ?? (mouseLocation, frame.origin)
        dragStart = start
        setFrameOrigin(NSPoint(
            x: start.origin.x + mouseLocation.x - start.mouseLocation.x,
            y: start.origin.y + mouseLocation.y - start.mouseLocation.y
        ))
        let now = ProcessInfo.processInfo.systemUptime
        dragSamples.append((mouseLocation, now))
        dragSamples.removeAll { now - $0.time > 0.1 }
    }

    func endDrag() {
        snapToEdge(throwVelocity: throwVelocity(), animated: true)
        dragStart = nil
        dragSamples = []
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        snapToEdge(animated: true)
    }

    private func throwVelocity() -> CGVector {
        guard let first = dragSamples.first, let last = dragSamples.last,
              last.time - first.time > 0.01 else { return .zero }
        let elapsed = last.time - first.time
        func clamped(_ speed: CGFloat) -> CGFloat {
            min(max(speed, -Self.maximumThrowSpeed), Self.maximumThrowSpeed)
        }
        return CGVector(
            dx: clamped((last.location.x - first.location.x) / elapsed),
            dy: clamped((last.location.y - first.location.y) / elapsed)
        )
    }

    private func snapToEdge(throwVelocity: CGVector = .zero, animated: Bool) {
        let landingPoint = NSPoint(
            x: frame.midX + throwVelocity.dx * Self.throwProjection,
            y: frame.midY + throwVelocity.dy * Self.throwProjection
        )
        let landingScreen = NSScreen.screens.first { $0.frame.contains(landingPoint) } ?? screen ?? NSScreen.main
        guard let visibleFrame = landingScreen?.visibleFrame else { return }
        let area = visibleFrame.insetBy(dx: Self.screenMargin, dy: Self.screenMargin)
        let cornerZone = area.height / 4
        let originX = landingPoint.x < area.midX ? area.minX : area.maxX - frame.width
        let originY: CGFloat
        if landingPoint.y < area.minY + cornerZone {
            originY = area.minY
        } else if landingPoint.y > area.maxY - cornerZone {
            originY = area.maxY - frame.height
        } else {
            originY = min(max(landingPoint.y - frame.height / 2, area.minY), area.maxY - frame.height)
        }
        let target = NSRect(origin: NSPoint(x: originX, y: originY), size: frame.size)
        guard target != frame else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
                animator().setFrame(target, display: true)
            }
        } else {
            setFrame(target, display: true)
        }
    }
}
