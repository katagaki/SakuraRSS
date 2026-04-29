import SwiftUI

struct SettingsIconLabel: View {

    let title: String
    let systemImage: String
    let color: Color
    let size: CGFloat

    init(_ title: String, systemImage: String, color: Color, size: CGFloat = 30) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.size = size
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            BorderedIcon(
                systemImage: systemImage,
                color: color
            )
        }
    }
}
