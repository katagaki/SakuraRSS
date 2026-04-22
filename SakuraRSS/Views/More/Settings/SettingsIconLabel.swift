import SwiftUI

struct SettingsIconLabel: View {

    let title: String
    let systemImage: String
    let color: Color
    let size: CGFloat

    init(_ title: String, systemImage: String, color: Color, size: CGFloat = 28) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.size = size
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.28))
        }
    }
}
