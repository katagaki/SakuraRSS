import SwiftUI

/// A read-only text view that supports proper range selection with drag handles.
/// Parses inline formatting: Markdown-style `[text](url)` links, `**bold**`,
/// `*italic*`, heading prefixes (`# `, `## `, `### `), and `{{SUP}}`/`{{SUB}}` markers.
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

    private func buildAttributedString() -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            if index > 0 {
                attributed.append(NSAttributedString(
                    string: "\n",
                    attributes: [.font: font, .foregroundColor: textColor]
                ))
            }

            var contentLine = line
            var lineFont = font

            // Detect heading prefixes
            if contentLine.hasPrefix("### ") {
                contentLine = String(contentLine.dropFirst(4))
                lineFont = UIFont.preferredFont(forTextStyle: .headline)
            } else if contentLine.hasPrefix("## ") {
                contentLine = String(contentLine.dropFirst(3))
                lineFont = UIFont.preferredFont(forTextStyle: .title2)
            } else if contentLine.hasPrefix("# ") {
                contentLine = String(contentLine.dropFirst(2))
                lineFont = UIFont.preferredFont(forTextStyle: .title1)
            }

            attributed.append(parseInlineFormatting(contentLine, baseFont: lineFont))
        }

        return attributed
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func parseInlineFormatting(_ text: String, baseFont: UIFont) -> NSAttributedString {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor
        ]

        // Order matters: ** before * to avoid conflicts
        let pattern = [
            #"\*\*(.+?)\*\*"#,                         // bold (group 1)
            #"\*(.+?)\*"#,                              // italic (group 2)
            #"\[([^\]]+)\]\(([^)]+)\)"#,                // link text (group 3) + url (group 4)
            #"\{\{SUP\}\}(.+?)\{\{/SUP\}\}"#,           // superscript (group 5)
            #"\{\{SUB\}\}(.+?)\{\{/SUB\}\}"#            // subscript (group 6)
        ].joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
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

            // Append plain text before this match
            if matchRange.location > lastEnd {
                let before = nsText.substring(
                    with: NSRange(location: lastEnd, length: matchRange.location - lastEnd)
                )
                attributed.append(NSAttributedString(string: before, attributes: baseAttributes))
            }

            if match.range(at: 1).location != NSNotFound {
                // Bold **text**
                let content = nsText.substring(with: match.range(at: 1))
                var attrs = baseAttributes
                attrs[.font] = baseFont.bold()
                attributed.append(NSAttributedString(string: content, attributes: attrs))
            } else if match.range(at: 2).location != NSNotFound {
                // Italic *text*
                let content = nsText.substring(with: match.range(at: 2))
                var attrs = baseAttributes
                attrs[.font] = baseFont.italic()
                attributed.append(NSAttributedString(string: content, attributes: attrs))
            } else if match.range(at: 3).location != NSNotFound {
                // Link [text](url)
                let linkText = nsText.substring(with: match.range(at: 3))
                let linkURL = nsText.substring(with: match.range(at: 4))
                var attrs = baseAttributes
                if let url = URL(string: linkURL) {
                    attrs[.link] = url
                }
                attributed.append(NSAttributedString(string: linkText, attributes: attrs))
            } else if match.range(at: 5).location != NSNotFound {
                // Superscript
                let content = nsText.substring(with: match.range(at: 5))
                var attrs = baseAttributes
                let smallFont = baseFont.withSize(baseFont.pointSize * 0.75)
                attrs[.font] = smallFont
                attrs[.baselineOffset] = baseFont.pointSize * 0.3
                attributed.append(NSAttributedString(string: content, attributes: attrs))
            } else if match.range(at: 6).location != NSNotFound {
                // Subscript
                let content = nsText.substring(with: match.range(at: 6))
                var attrs = baseAttributes
                let smallFont = baseFont.withSize(baseFont.pointSize * 0.75)
                attrs[.font] = smallFont
                attrs[.baselineOffset] = -baseFont.pointSize * 0.2
                attributed.append(NSAttributedString(string: content, attributes: attrs))
            }

            lastEnd = matchRange.location + matchRange.length
        }

        // Append any remaining text after the last match
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

    func italic() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitItalic) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
