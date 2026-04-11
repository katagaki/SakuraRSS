import SwiftUI
import UIKit

struct InitialsAvatarView: View {

    let name: String
    let size: CGFloat
    let isCircle: Bool
    let cornerRadius: CGFloat

    init(_ name: String, size: CGFloat = 20, circle: Bool = false, cornerRadius: CGFloat = 3) {
        self.name = name
        self.size = size
        self.isCircle = circle
        self.cornerRadius = cornerRadius
    }

    private var initials: String {
        Self.initials(for: name)
    }

    private var backgroundColor: Color {
        Self.backgroundColor(for: name)
    }

    var body: some View {
        Group {
            if Self.isGlyphBased(name) {
                Image(systemName: "newspaper")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(backgroundColor)
        .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
    }

    // MARK: - Shared Helpers

    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        let letters = words.prefix(2).compactMap(\.first).map(String.init)
        let result = letters.joined().uppercased()
        if result.isEmpty, let first = name.first {
            return String(first).uppercased()
        }
        return result
    }

    static func isGlyphBased(_ name: String) -> Bool {
        let letters = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let glyphScalars = letters.filter { scalar in
            // CJK Unified Ideographs, Hiragana, Katakana, Hangul Syllables, Hangul Jamo
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3040...0x309F).contains(scalar.value) ||
            (0x30A0...0x30FF).contains(scalar.value) ||
            (0xAC00...0xD7AF).contains(scalar.value) ||
            (0x1100...0x11FF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value) ||
            (0x20000...0x2A6DF).contains(scalar.value)
        }
        return glyphScalars.count > letters.count / 2
    }

    static func backgroundColor(for name: String) -> Color {
        let hash = name.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.45, brightness: 0.75)
    }

    // MARK: - UIImage Rendering

    static func renderToImage(name: String, size: CGFloat = 128) -> UIImage? {
        let hash = name.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        let hue = CGFloat(abs(hash) % 360) / 360.0
        let bgColor = UIColor(hue: hue, saturation: 0.45, brightness: 0.75, alpha: 1.0)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))

            // Draw rounded rectangle background
            let cornerRadius = size / 8
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            bgColor.setFill()
            path.fill()

            if isGlyphBased(name) {
                // Draw newspaper SF Symbol for glyph-based languages
                let fontSize = size * 0.4
                let config = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .semibold)
                if let symbol = UIImage(systemName: "newspaper", withConfiguration: config)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let symbolSize = symbol.size
                    let symbolRect = CGRect(
                        x: (size - symbolSize.width) / 2,
                        y: (size - symbolSize.height) / 2,
                        width: symbolSize.width,
                        height: symbolSize.height
                    )
                    symbol.draw(in: symbolRect)
                }
            } else {
                // Draw initials text for Latin-based languages
                let initials = initials(for: name)
                let fontSize = size * 0.4
                let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
                    .rounded
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                let textSize = (initials as NSString).size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size - textSize.width) / 2,
                    y: (size - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                (initials as NSString).draw(in: textRect, withAttributes: attributes)
            }
        }
    }
}

private extension UIFont {
    var rounded: UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
