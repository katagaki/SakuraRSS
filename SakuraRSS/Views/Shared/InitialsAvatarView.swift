import SwiftUI

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

    private var initials: String {
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        let letters = words.prefix(2).compactMap(\.first).map(String.init)
        let result = letters.joined().uppercased()
        if result.isEmpty, let first = name.first {
            return String(first).uppercased()
        }
        return result
    }

    private var backgroundColor: Color {
        let hash = name.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.45, brightness: 0.75)
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(backgroundColor)
            .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
    }
}
