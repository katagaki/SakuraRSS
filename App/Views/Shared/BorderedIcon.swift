import SwiftUI

struct BorderedIcon: View {

    let systemImage: String
    let background: AnyShapeStyle
    let size: CGFloat
    let iconSizeFactor: CGFloat
    let cornerRadius: CGFloat?

    init(
        systemImage: String,
        color: Color,
        size: CGFloat = 30,
        iconSizeFactor: CGFloat = 0.42,
        cornerRadius: CGFloat? = nil
    ) {
        self.systemImage = systemImage
        self.background = AnyShapeStyle(color.gradient)
        self.size = size
        self.iconSizeFactor = iconSizeFactor
        self.cornerRadius = cornerRadius
    }

    init(
        systemImage: String,
        gradient: LinearGradient,
        size: CGFloat = 30,
        iconSizeFactor: CGFloat = 0.42,
        cornerRadius: CGFloat? = nil
    ) {
        self.systemImage = systemImage
        self.background = AnyShapeStyle(gradient)
        self.size = size
        self.iconSizeFactor = iconSizeFactor
        self.cornerRadius = cornerRadius
    }

    init(
        systemImage: String,
        background: AnyShapeStyle,
        size: CGFloat = 30,
        iconSizeFactor: CGFloat = 0.42,
        cornerRadius: CGFloat? = nil
    ) {
        self.systemImage = systemImage
        self.background = background
        self.size = size
        self.iconSizeFactor = iconSizeFactor
        self.cornerRadius = cornerRadius
    }

    private var resolvedCornerRadius: CGFloat {
        cornerRadius ?? size * 0.28
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * iconSizeFactor, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: resolvedCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: resolvedCornerRadius)
                    .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
            }
    }
}
