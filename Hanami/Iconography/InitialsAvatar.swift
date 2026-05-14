import Foundation
import UIKit

public enum InitialsAvatar {

    public nonisolated static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        let letters = words.prefix(2).compactMap(\.first).map(String.init)
        let result = letters.joined().uppercased()
        if result.isEmpty, let first = name.first {
            return String(first).uppercased()
        }
        return result
    }

    public nonisolated static func isGlyphBased(_ name: String) -> Bool {
        let letters = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_.,:;!?'\"()[]{}&@#/\\*+=<>|~`^$%"))
        let nonStandard = name.unicodeScalars.filter { !allowed.contains($0) }
        return nonStandard.count > letters.count / 2
    }

    public nonisolated static func backgroundHue(for name: String) -> CGFloat {
        let hash = name.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return CGFloat(abs(hash) % 360) / 360.0
    }

    public nonisolated static func renderToImage(name: String, size: CGFloat = 128) -> UIImage? {
        let bgColor = UIColor(hue: backgroundHue(for: name), saturation: 0.45, brightness: 0.75, alpha: 1.0)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))

            let cornerRadius = size / 8
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            bgColor.setFill()
            path.fill()

            if isGlyphBased(name) {
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
                let initials = initials(for: name)
                let fontSize = size * 0.4
                let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold).rounded
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
    nonisolated var rounded: UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
