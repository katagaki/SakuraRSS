import AppKit

func newYork(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let system = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = system.fontDescriptor.withDesign(.serif) else { return system }
    return NSFont(descriptor: descriptor, size: size) ?? system
}

/// One line of text at the largest size up to `size` that fits `maxWidth`.
@MainActor
struct Line {
    let text: String
    let attributes: [NSAttributedString.Key: Any]
    let size: NSSize

    init(_ text: String, size: CGFloat, weight: NSFont.Weight, maxWidth: CGFloat) {
        var fontSize = size
        var attributes: [NSAttributedString.Key: Any] = [:]
        var lineSize = NSSize.zero
        while fontSize > 10 {
            attributes = [
                .font: newYork(size: fontSize, weight: weight),
                .foregroundColor: Palette.text
            ]
            lineSize = (text as NSString).size(withAttributes: attributes)
            if lineSize.width <= maxWidth { break }
            fontSize -= 2
        }
        self.text = text
        self.attributes = attributes
        self.size = lineSize
    }

    /// Draws the line centered on `centerX`, with the top of its line box at `top`.
    func draw(top: CGFloat, centerX: CGFloat) {
        (text as NSString).draw(
            at: NSPoint(x: centerX - size.width / 2, y: top - size.height),
            withAttributes: attributes
        )
    }
}
