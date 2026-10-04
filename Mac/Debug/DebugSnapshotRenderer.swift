#if DEBUG
import AppKit

/// Writes the key window, toolbar included, to the PNG path passed as
/// `-DebugSnapshotPath`, for checking layouts when no display can be captured.
/// Materials don't render offscreen, so sidebars come out without their blur.
enum DebugSnapshotRenderer {

    static func scheduleIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "DebugSnapshotPath") else { return }
        let delay = UserDefaults.standard.double(forKey: "DebugSnapshotDelay")
        DispatchQueue.main.asyncAfter(deadline: .now() + (delay > 0 ? delay : 2)) {
            render(to: URL(fileURLWithPath: path))
        }
    }

    private static func render(to url: URL) {
        guard UserDefaults.standard.bool(forKey: "DebugSnapshotAllWindows") else {
            let settingsWindow = UserDefaults.standard.object(forKey: "DebugOpenSettingsTab") == nil ? nil
                : NSApp.windows.first { $0.contentViewController is NSTabViewController }
            if let window = settingsWindow ?? NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) {
                render(window, to: url)
            }
            return
        }
        let windows = NSApp.windows.filter { $0.windowController is BrowserWindowController }
        for (index, window) in windows.enumerated() {
            let name = url.deletingPathExtension().lastPathComponent + "-\(index).png"
            render(window, to: url.deletingLastPathComponent().appendingPathComponent(name))
        }
    }

    private static func render(_ window: NSWindow, to url: URL) {
        guard let windowFrameView = window.contentView?.superview else { return }
        let frameView = UserDefaults.standard.string(forKey: "DebugSnapshotViewClass")
            .flatMap { firstSubview(named: $0, in: windowFrameView) } ?? windowFrameView
        guard let layer = frameView.layer else { return }
        let scale = window.backingScaleFactor
        let size = frameView.bounds.size
        guard let context = CGContext(
            data: nil,
            width: Int(size.width * scale),
            height: Int(size.height * scale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        context.scaleBy(x: scale, y: scale)
        if frameView.isFlipped {
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
        }
        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        layer.render(in: context)
        guard let image = context.makeImage() else { return }
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
    }

    private static func firstSubview(named className: String, in view: NSView) -> NSView? {
        if NSStringFromClass(type(of: view)) == className { return view }
        for subview in view.subviews {
            if let match = firstSubview(named: className, in: subview) { return match }
        }
        return nil
    }
}
#endif
