import SwiftUI
import Hanami

struct InitialsAvatarView: View {

    let name: String
    let size: CGFloat
    let isCircle: Bool
    let cornerRadius: CGFloat

    init(_ name: String, size: CGFloat = 20, circle: Bool = false, cornerRadius: CGFloat = 3) {
        self.name = name
        self.size = size
        self.isCircle = circle
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if InitialsAvatar.isGlyphBased(name) {
                Image(systemName: "newspaper")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(InitialsAvatar.initials(for: name))
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(Self.backgroundColor(for: name))
        .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
    }

    private static func backgroundColor(for name: String) -> Color {
        Color(hue: InitialsAvatar.backgroundHue(for: name), saturation: 0.45, brightness: 0.75)
    }
}
