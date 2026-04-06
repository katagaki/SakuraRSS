import SwiftUI

/// A read-only text view that supports proper range selection with drag handles.
/// Uses Apple's `AttributedString(markdown:)` parser for inline formatting (bold, italic,
/// links, strikethrough, code), with additional support for heading prefixes
/// (`# `, `## `, `### `) and custom `{{SUP}}`/`{{SUB}}` markers.
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
        textView.invalidateIntrinsicContentSize()
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

            attributed.append(parseLine(contentLine, baseFont: lineFont))
        }

        return attributed
    }

    /// Splits a line around `{{SUP}}…{{/SUP}}` and `{{SUB}}…{{/SUB}}` markers,
    /// parsing the remaining segments as standard Markdown.
    private func parseLine(_ text: String, baseFont: UIFont) -> NSAttributedString {
        let supSubPattern = #"\{\{(SUP|SUB)\}\}(.+?)\{\{/(SUP|SUB)\}\}"#
        guard let supSubRegex = try? NSRegularExpression(pattern: supSubPattern) else {
            return parseMarkdown(text, baseFont: baseFont)
        }

        let nsText = text as NSString
        let matches = supSubRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else {
            return parseMarkdown(text, baseFont: baseFont)
        }

        let result = NSMutableAttributedString()
        var lastEnd = 0

        for match in matches {
            if match.range.location > lastEnd {
                let before = nsText.substring(
                    with: NSRange(location: lastEnd, length: match.range.location - lastEnd)
                )
                result.append(parseMarkdown(before, baseFont: baseFont))
            }

            let tag = nsText.substring(with: match.range(at: 1))
            let content = nsText.substring(with: match.range(at: 2))
            let smallFont = baseFont.withSize(baseFont.pointSize * 0.75)
            var attrs: [NSAttributedString.Key: Any] = [
                .font: smallFont,
                .foregroundColor: textColor
            ]
            attrs[.baselineOffset] = tag == "SUP"
                ? baseFont.pointSize * 0.3
                : -baseFont.pointSize * 0.2
            result.append(NSAttributedString(string: content, attributes: attrs))

            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
            result.append(parseMarkdown(remaining, baseFont: baseFont))
        }

        return result
    }

    /// Parses standard Markdown using `AttributedString(markdown:)` and converts
    /// Foundation attributes into UIKit attributes for the text view.
    private func parseMarkdown(_ text: String, baseFont: UIFont) -> NSAttributedString {
        guard !text.isEmpty else {
            return NSAttributedString()
        }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let parsed = try? AttributedString(markdown: text, options: options) else {
            return NSAttributedString(
                string: text,
                attributes: [.font: baseFont, .foregroundColor: textColor]
            )
        }

        let result = NSMutableAttributedString()

        for run in parsed.runs {
            let runText = String(parsed[run.range].characters)
            var attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: textColor
            ]

            if let intent = run.inlinePresentationIntent {
                var traits: UIFontDescriptor.SymbolicTraits = []
                if intent.contains(.stronglyEmphasized) {
                    traits.insert(.traitBold)
                }
                if intent.contains(.emphasized) {
                    traits.insert(.traitItalic)
                }
                if !traits.isEmpty,
                   let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                    attrs[.font] = UIFont(descriptor: descriptor, size: 0)
                }
                if intent.contains(.strikethrough) {
                    attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
                if intent.contains(.code) {
                    attrs[.font] = UIFont.monospacedSystemFont(
                        ofSize: baseFont.pointSize, weight: .regular
                    )
                }
            }

            if let link = run.link {
                attrs[.link] = link
            }

            result.append(NSAttributedString(string: runText, attributes: attrs))
        }

        return result
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
