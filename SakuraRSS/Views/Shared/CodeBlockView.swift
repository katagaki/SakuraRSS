import SwiftUI

/// A styled view for displaying code blocks extracted from `<pre>` elements.
/// Shows monospaced text with a tinted background and horizontal scrolling for long lines.
struct CodeBlockView: View {

    let code: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
