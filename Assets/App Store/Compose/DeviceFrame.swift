import AppKit

func loadImage(_ url: URL) -> CGImage? {
    guard let image = NSImage(contentsOf: url) else { return nil }
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

/// A hardware image, and the mask of its display placed at `displayOrigin` in the hardware's pixels.
struct DeviceFrame {
    let hardware: CGImage
    let display: CGImage
    /// Measured from the hardware's top left.
    let displayOrigin: NSPoint

    init(name: String, displayOrigin: NSPoint? = nil) {
        let frames = assetsDir.appendingPathComponent("Frames")
        hardware = loadImage(frames.appendingPathComponent("\(name) Hardware.png"))
            ?? loadImage(frames.appendingPathComponent("\(name) Hardware@2x.png"))!
        display = loadImage(frames.appendingPathComponent("\(name) Display.png"))
            ?? loadImage(frames.appendingPathComponent("\(name) Display@2x.png"))!
        // Without an origin, the display sits centered within the hardware.
        self.displayOrigin = displayOrigin ?? NSPoint(
            x: CGFloat(hardware.width - display.width) / 2,
            y: CGFloat(hardware.height - display.height) / 2
        )
    }

    var hardwareSize: NSSize { NSSize(width: hardware.width, height: hardware.height) }
    var displaySize: NSSize { NSSize(width: display.width, height: display.height) }
}

@MainActor
enum DeviceFrames {
    static let iPhone = DeviceFrame(name: "iPhone")
    static let iPad = DeviceFrame(name: "iPad", displayOrigin: NSPoint(x: 95, y: 95))
    static let mac = DeviceFrame(name: "Mac", displayOrigin: NSPoint(x: 323, y: 66))

    static func frame(for device: Device) -> DeviceFrame {
        switch device {
        case .iPhone: iPhone
        case .iPad: iPad
        case .mac: mac
        }
    }
}
