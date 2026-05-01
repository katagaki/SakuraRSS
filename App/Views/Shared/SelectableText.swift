import SwiftUI

/// Read-only text view with range selection, Markdown formatting, and `{{SUP}}`/`{{SUB}}` markers.
struct SelectableText: UIViewRepresentable {

    let text: String
    let font: UIFont
    let textColor: UIColor
    var onLinkTap: ((URL) -> Void)?

    init(_ text: String, font: UIFont = .preferredFont(forTextStyle: .body),
         textColor: UIColor = .label,
         onLinkTap: ((URL) -> Void)? = nil) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.onLinkTap = onLinkTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTap: onLinkTap)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.dataDetectorTypes = []
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onLinkTap = onLinkTap
        textView.attributedText = buildAttributedString()
        textView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context _: Context) -> CGSize? {
        if let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth > 0 {
            let size = uiView.sizeThatFits(
                CGSize(width: proposedWidth, height: CGFloat.greatestFiniteMagnitude)
            )
            return CGSize(width: proposedWidth, height: size.height)
        }
        return uiView.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTap: ((URL) -> Void)?

        init(onLinkTap: ((URL) -> Void)?) {
            self.onLinkTap = onLinkTap
        }

        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            guard let onLinkTap, case .link(let url) = textItem.content else {
                return defaultAction
            }
            return UIAction { _ in onLinkTap(url) }
        }
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

    /// Splits around `{{SUP/SUB}}` markers and parses remaining segments as Markdown.
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

    /// Parses Markdown via `AttributedString` and converts to UIKit attributes.
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
