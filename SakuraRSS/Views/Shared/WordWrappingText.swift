import SwiftUI

/// A text view that uses strict word wrapping via UILabel,
/// preventing the system from breaking lines mid-word at punctuation like apostrophes.
struct WordWrappingText: UIViewRepresentable {

    let text: String
    let font: UIFont

    init(_ text: String, font: UIFont = .preferredFont(forTextStyle: .body)) {
        self.text = text
        self.font = font
    }

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.lineBreakStrategy = []
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
        label.font = font
        label.textColor = .label
    }
}

extension UIFont {
    static func preferredFont(forTextStyle style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: descriptor, size: 0)
    }
}
