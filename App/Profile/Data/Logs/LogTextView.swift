import SwiftUI
import UIKit

struct LogTextView: UIViewRepresentable {

    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .clear
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            DispatchQueue.main.async {
                scrollToBottom(uiView)
            }
        }
    }

    private func scrollToBottom(_ textView: UITextView) {
        guard !textView.text.isEmpty else { return }
        let range = NSRange(location: textView.text.utf16.count - 1, length: 1)
        textView.scrollRangeToVisible(range)
    }
}
