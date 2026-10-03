import SwiftUI

/// Safari's numbered square, sized to sit inside a toolbar item.
struct BrowserTabCountLabel: View {

    let count: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(lineWidth: 1.5)
                .frame(width: 19, height: 19)
            Text(verbatim: count > 99 ? "99+" : "\(count)")
                .font(.system(size: count > 99 ? 8 : 11, weight: .semibold))
                .monospacedDigit()
        }
        .frame(width: 22, height: 22)
    }
}
