import SwiftUI

/// A read-only text view that supports proper range selection with drag handles.
/// Parses Markdown-style `[text](url)` links into tappable links.
struct SelectableText: UIViewRepresentable {

    let text: String
    let font: UIFont
    let textColor: UIColor

    init(_ text: String, font: UIFont = .preferredFont(forTextStyle: .body),
         textColor: UIColor = .label) {
        self.text = text
        self.font = font
        self.textColor = textColor
    }

    func makeUIView(context _: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.dataDetectorTypes = []
        return textView
    }

    func updateUIView(_ textView: UITextView, context _: Context) {
        textView.attributedText = buildAttributedString()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context _: Context) -> CGSize? {
        let fallbackWidth = uiView.window?.windowScene?.screen.bounds.width ?? 390
        let width = proposal.width ?? fallbackWidth
        let size = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    /// Parses Markdown-style `[text](url)` links and builds an attributed string
    /// with tappable `.link` attributes for each match.
    private func buildAttributedString() -> NSAttributedString {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) else {
            return NSAttributedString(string: text, attributes: baseAttributes)
        }

        let nsText = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard !results.isEmpty else {
            return NSAttributedString(string: text, attributes: baseAttributes)
        }

        let attributed = NSMutableAttributedString()
        var lastEnd = 0

        for match in results {
            let matchRange = match.range
            // Append text before this link
            if matchRange.location > lastEnd {
                let before = nsText.substring(with: NSRange(location: lastEnd, length: matchRange.location - lastEnd))
                attributed.append(NSAttributedString(string: before, attributes: baseAttributes))
            }

            let linkText = nsText.substring(with: match.range(at: 1))
            let linkURL = nsText.substring(with: match.range(at: 2))

            var linkAttributes = baseAttributes
            if let url = URL(string: linkURL) {
                linkAttributes[.link] = url
            }
            attributed.append(NSAttributedString(string: linkText, attributes: linkAttributes))

            lastEnd = matchRange.location + matchRange.length
        }

        // Append any remaining text after the last link
        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
            attributed.append(NSAttributedString(string: remaining, attributes: baseAttributes))
        }

        return attributed
    }
}

extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
