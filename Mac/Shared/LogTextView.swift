import SwiftUI

/// The Mac's stand-in for iOS's `LogTextView`, which wraps `UITextView`.
struct LogTextView: View {

    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .id("log")
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: text) {
                proxy.scrollTo("log", anchor: .bottom)
            }
        }
    }
}
