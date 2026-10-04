import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

/// Sakura's lavender, and the colors given to each kind of content.
@MainActor
enum Palette {
    static let text = color(0x1B1616)
    static let lavender = Gradient(stops: [(color(0xC7B4F8), 0), (color(0xEAD0E3), 0.87)])
    static let blossom = Gradient(stops: [(color(0xF8B4C4), 0), (color(0xFFFFFF), 0.87)])
    static let meadow = Gradient(stops: [(color(0x4D6848), 0), (color(0xCEFDD1), 0.49)])
    static let sunset = Gradient(stops: [
        (color(0xF8D8B4), 0), (color(0xFDCBC8), 0.25), (color(0xFFC3D4), 0.57), (color(0xF6BFEF), 1)
    ])
    static let sunrise = Gradient(stops: [(color(0xFFC3DB), 0), (color(0xF8C7BD), 0.39), (color(0xF8D8B4), 1)])
    static let alert = Gradient(stops: [(color(0xFFC3C3), 0), (color(0xBDF8B4), 1)])
}
