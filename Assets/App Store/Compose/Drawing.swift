import AppKit

struct MissingCapture: Error {
    let url: URL
}

/// Where a spread is being drawn, and for which device and language.
struct DrawingTarget {
    let device: Device
    let language: String
    let context: CGContext

    func capture(_ name: String) throws -> CGImage {
        let url = device.rawURL(name, language: language)
        guard let image = loadImage(url) else { throw MissingCapture(url: url) }
        return image
    }
}

/// Draws `image` aspect-filled into `rect`.
func drawFilled(_ image: CGImage, in rect: CGRect, context: CGContext) {
    let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
    let drawSize = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    context.draw(image, in: CGRect(
        x: rect.midX - drawSize.width / 2,
        y: rect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    ))
}

/// Draws the screen into `rect`, the display of an unrotated frame.
@MainActor
func drawScreen(_ placement: Placement, in rect: CGRect, target: DrawingTarget) throws {
    let context = target.context
    switch placement.screen {
    case .capture(let name):
        let image = try target.capture(name)
        guard placement.orientation == .landscape else {
            drawFilled(image, in: rect, context: context)
            return
        }
        // The frame is drawn turned a quarter turn, so the capture is turned back to stay upright.
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: -.pi / 2)
        drawFilled(
            image,
            in: CGRect(x: -rect.height / 2, y: -rect.width / 2, width: rect.height, height: rect.width),
            context: context
        )
        context.restoreGState()
    case .desktop(let wallpaper, let windows):
        drawFilled(try target.capture(wallpaper), in: rect, context: context)
        let scale = rect.width / DeviceFrames.frame(for: target.device).displaySize.width
        for window in windows {
            let image = try target.capture(window.rawName)
            let width = window.width * scale
            let height = width * CGFloat(image.height) / CGFloat(image.width)
            // Window centers are measured downward, as on screen.
            context.draw(image, in: CGRect(
                x: rect.midX + window.center.x * scale - width / 2,
                y: rect.midY - window.center.y * scale - height / 2,
                width: width,
                height: height
            ))
        }
    }
}

@MainActor
func drawDevice(_ placement: Placement, spreadHeight: CGFloat, target: DrawingTarget) throws {
    let context = target.context
    let frame = DeviceFrames.frame(for: target.device)
    let hardwareSize = frame.hardwareSize
    let isLandscape = placement.orientation == .landscape
    let scale = placement.width / (isLandscape ? hardwareSize.height : hardwareSize.width)
    let size = NSSize(width: hardwareSize.width * scale, height: hardwareSize.height * scale)

    context.saveGState()
    defer { context.restoreGState() }
    context.translateBy(x: placement.center.x, y: spreadHeight - placement.center.y)
    if isLandscape {
        // The iPad's camera sits on its long edge, so it is turned to bring that edge to the top.
        context.rotate(by: .pi / 2)
    }
    let hardwareRect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -24),
        blur: 60,
        color: NSColor.black.withAlphaComponent(0.25).cgColor
    )
    context.draw(frame.hardware, in: hardwareRect)
    context.restoreGState()

    // The display origin is measured from the hardware's top left, and CoreGraphics counts up.
    let displayRect = CGRect(
        x: hardwareRect.minX + frame.displayOrigin.x * scale,
        y: hardwareRect.maxY - (frame.displayOrigin.y + frame.displaySize.height) * scale,
        width: frame.displaySize.width * scale,
        height: frame.displaySize.height * scale
    )
    context.saveGState()
    context.clip(to: displayRect, mask: frame.display)
    try drawScreen(placement, in: displayRect, target: target)
    context.restoreGState()
}
