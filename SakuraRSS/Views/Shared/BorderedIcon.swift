import SwiftUI

struct BorderedIcon: View {

    let systemImage: String
    let color: Color
    let size: CGFloat
    let iconSizeFactor: CGFloat

    init(
        systemImage: String,
        color: Color,
        size: CGFloat = 30,
        iconSizeFactor: CGFloat = 0.42
    ) {
        self.systemImage = systemImage
        self.color = color
        self.size = size
        self.iconSizeFactor = iconSizeFactor
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * iconSizeFactor, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.28))
    }
}
