import AppKit
import Hanami
import SwiftUI

/// SwiftUI `Text` can't draw ruby, so paragraphs with furigana use a TextKit 2 `NSTextView`.
struct RubyTextView: NSViewRepresentable {

    let text: String
    let fontSize: CGFloat

    @Environment(\.openURL) private var openURL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.delegate = context.coordinator
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        context.coordinator.openURL = openURL
        guard context.coordinator.renderedText != text else { return }
        context.coordinator.renderedText = text
        textView.textStorage?.setAttributedString(attributedText())
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView textView: NSTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0,
              let textContainer = textView.textContainer,
              let layoutManager = textView.textLayoutManager else { return nil }
        textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        let height = layoutManager.usageBoundsForTextContainer.height
        return CGSize(width: width, height: ceil(height))
    }

    private func attributedText() -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: fontSize)
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = (font.ascender - font.descender + font.leading) + fontSize * 0.6
        let result = NSMutableAttributedString()
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(markdownLine(line, font: font))
        }
        result.addAttributes(
            [.paragraphStyle: style, .foregroundColor: NSColor.labelColor],
            range: NSRange(location: 0, length: result.length)
        )
        result.applyRubyAnnotations()
        return result
    }

    private func markdownLine(_ line: String, font: NSFont) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let parsed = try? AttributedString(markdown: line, options: options) else {
            return NSAttributedString(string: line, attributes: [.font: font])
        }
        let result = NSMutableAttributedString()
        for run in parsed.runs {
            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            if let intent = run.inlinePresentationIntent {
                var traits: NSFontDescriptor.SymbolicTraits = []
                if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
                if intent.contains(.emphasized) { traits.insert(.italic) }
                if !traits.isEmpty {
                    let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                    attributes[.font] = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
                }
            }
            if let link = run.link {
                attributes[.link] = link
            }
            result.append(NSAttributedString(
                string: String(parsed[run.range].characters), attributes: attributes
            ))
        }
        return result
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var renderedText: String?
        var openURL: OpenURLAction?

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL, let openURL else { return false }
            openURL(url)
            return true
        }
    }
}
