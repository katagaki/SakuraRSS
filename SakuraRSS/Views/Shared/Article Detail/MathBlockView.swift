import SwiftUI

struct MathBlockView: View {

    let latex: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(latex)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
