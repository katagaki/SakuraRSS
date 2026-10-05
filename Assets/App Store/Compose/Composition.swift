import AppKit

@MainActor
func drawPanel(_ panel: Panel, in panelRect: NSRect, device: Device, language: String) {
    NSGradient(
        colors: panel.gradient.stops.map(\.0),
        atLocations: panel.gradient.stops.map(\.1),
        colorSpace: .sRGB
    )?.draw(in: panelRect, angle: 90)

    guard let copy = panel.copy[language] else { return }
    let header = Line(copy.header, size: device.headerSize, weight: .semibold, maxWidth: device.textWidth)
    let headerTop = panelRect.maxY - device.textTop
    header.draw(top: headerTop, centerX: panelRect.midX)
    if let captionText = copy.caption {
        let caption = Line(captionText, size: device.captionSize, weight: .regular, maxWidth: device.textWidth)
        caption.draw(top: headerTop - header.size.height, centerX: panelRect.midX)
    }
}

/// Draws a whole spread, backgrounds and text first and the devices over them.
@MainActor
func renderSpread(_ spread: Spread, language: String) throws -> CGImage? {
    let canvasSize = spread.device.canvasSize
    let spreadSize = NSSize(width: canvasSize.width * CGFloat(spread.panels.count), height: canvasSize.height)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(spreadSize.width), pixelsHigh: Int(spreadSize.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )?.retagging(with: .sRGB), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphics

    for (index, panel) in spread.panels.enumerated() {
        let panelRect = NSRect(
            x: canvasSize.width * CGFloat(index), y: 0,
            width: canvasSize.width, height: canvasSize.height
        )
        drawPanel(panel, in: panelRect, device: spread.device, language: language)
    }
    let target = DrawingTarget(device: spread.device, language: language, context: graphics.cgContext)
    for placement in spread.placements {
        try drawDevice(placement, spreadHeight: spreadSize.height, target: target)
    }
    graphics.flushGraphics()
    return bitmap.cgImage
}

/// Slices a spread back into its screenshots and writes each one out.
@MainActor
func writePanels(of spread: Spread, from spreadImage: CGImage, language: String) -> Bool {
    let canvasSize = spread.device.canvasSize
    let outDir = spread.device.outDir(language)
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    var allWritten = true
    for (index, panel) in spread.panels.enumerated() {
        let cropRect = CGRect(
            x: canvasSize.width * CGFloat(index), y: 0,
            width: canvasSize.width, height: canvasSize.height
        )
        let outURL = outDir.appendingPathComponent("\(panel.outName).png")
        guard let panelImage = spreadImage.cropping(to: cropRect),
              let png = NSBitmapImageRep(cgImage: panelImage).representation(using: .png, properties: [:]),
              (try? png.write(to: outURL)) != nil else {
            print("failed to write \(outURL.path)")
            allWritten = false
            continue
        }
        print("wrote \(outURL.path.replacingOccurrences(of: assetsDir.path + "/", with: ""))")
    }
    return allWritten
}

@MainActor
func compose(_ spread: Spread, language: String) -> Bool {
    // A spread is all or nothing, so its screenshots never go out of step with each other.
    guard spread.panels.allSatisfy({ $0.copy[language] != nil }) else { return true }
    do {
        guard let spreadImage = try renderSpread(spread, language: language) else { return false }
        return writePanels(of: spread, from: spreadImage, language: language)
    } catch let error as MissingCapture {
        print("missing raw capture: \(error.url.path)")
        return false
    } catch {
        print("failed to draw: \(error)")
        return false
    }
}
