import AppKit

struct Copy {
    let header: String
    var caption: String?
}

/// Color stops from the bottom of the canvas to the top.
struct Gradient {
    let stops: [(NSColor, CGFloat)]
}

/// One App Store screenshot: its copy and background. Devices are placed on the spread around it.
struct Panel {
    let outName: String
    /// Keyed by language code. A language without copy is skipped.
    let copy: [String: Copy]
    let gradient: Gradient
}

/// A window capture on the Mac's desktop, placed in the display's own pixels from its center.
/// It's drawn at its own pixel size times `scale`, so a capture at 1 lands pixel for pixel
/// and one at 0.5 is an even 2:1 reduction.
struct Window {
    let rawName: String
    let center: NSPoint
    var scale: CGFloat = 1
}

enum Screen {
    /// A device capture, filling the display.
    case capture(String)
    /// A wallpaper filling the display, with window captures over it.
    case desktop(wallpaper: String, windows: [Window])
}

enum Orientation {
    case portrait
    case landscape
}

/// A device on a spread. `center` is measured from the spread's top left, and `width`
/// is the width of the hardware as it appears, after any rotation.
struct Placement {
    let screen: Screen
    let center: NSPoint
    let width: CGFloat
    var orientation: Orientation = .portrait
}

/// Panels laid side by side, so that a device can run across the seam between two screenshots.
struct Spread {
    let device: Device
    let panels: [Panel]
    /// Drawn in order, so later devices sit on top.
    let placements: [Placement]
}
