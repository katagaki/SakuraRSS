import SwiftUI

/// UILabel-backed text view with strict word wrapping.
struct WordWrappingText: UIViewRepresentable {

    let text: String
    let font: UIFont

    init(_ text: String, font: UIFont = .preferredFont(forTextStyle: .body)) {
        self.text = text
        self.font = font
    }

    func makeUIView(context: Context) -> WrappingLabel {
        let label = WrappingLabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.lineBreakStrategy = []
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return label
    }

    func updateUIView(_ label: WrappingLabel, context: Context) {
        label.text = text
        label.font = font
        label.textColor = .label
    }
}

/// UILabel that sets preferredMaxLayoutWidth so multiline wraps correctly inside SwiftUI.
class WrappingLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        if preferredMaxLayoutWidth != bounds.width {
            preferredMaxLayoutWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }
}

extension UIFont {
    static func preferredFont(forTextStyle style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: descriptor, size: 0)
    }
}
