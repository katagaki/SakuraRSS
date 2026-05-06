import SwiftUI

extension ListIcon {

    /// Two-color palette for the list's bordered icon and home tab pill.
    /// Colors are chosen to thematically match each icon (warm tones for food,
    /// cool tones for tech, etc.) while leaving enough contrast for white glyphs.
    var gradientColors: (Color, Color) {
        switch self {
        case .newspaper: (.gray.darken(by: 0.4), .black)
        case .bookClosed: (.brown, .brown.darken())
        case .globe: (.blue, .green)
        case .megaphone: (.red, .pink)
        case .exclamationmarkTriangle: (.red, .red.darken())
        case .flame: (.yellow, .orange)
        case .bolt: (.yellow, .yellow.darken())
        case .eyeglasses: (.indigo, .indigo.darken())
        case .magnifyingglass: (.cyan, .blue)
        case .textQuote: (.white.darken(), .white.darken(by: 0.5))

        case .laptopcomputer: (.cyan, .blue)
        case .iphone: (.cyan, .blue)
        case .serverRack: (.cyan, .blue)
        case .cpu: (.cyan, .blue)
        case .wifi: (.blue.lighten(), .blue)
        case .antenna: (.blue.lighten(), .blue)
        case .atom: (.blue.darken(by: 0.6), .blue.darken(by: 0.8))
        case .flask: (.teal, .green.darken(by: 0.1))
        case .stethoscope: (.red.lighten(), .red)
        case .cross: (.red, .pink)

        case .sportscourt: (.green, .green.darken())
        case .figureRun: (.lime, .lime.darken())
        case .soccerball: (.lime, .lime.darken())
        case .basketball: (.lime, .lime.darken())
        case .football: (.lime, .lime.darken())
        case .tennisRacket: (.lime, .lime.darken())
        case .trophy: (.yellow, .yellow.darken())
        case .medal: (.yellow, .yellow.darken())
        case .bicycle: (.lime, .lime.darken())
        case .dumbbell: (.lime, .lime.darken())

        case .film: (.magenta, .magenta.darken())
        case .tv: (.slate, .slate.darken())
        case .playRectangle: (.red, .red.darken())
        case .theatermasks: (.purple, .magenta)
        case .popcorn: (.yellow, .red)
        case .camera: (.indigo.lighten(), .indigo)
        case .videoCamera: (.indigo.lighten(), .indigo)
        case .rectangleOnRectangle: (.gray, .gray.darken())
        case .sparkles: (.yellow, .pink)
        case .wand: (.pink, .purple)

        case .musicNote: (.pink.lighten(), .pink)
        case .musicMic: (.pink.lighten(), .pink)
        case .headphones: (.pink.lighten(), .pink)
        case .micFill: (.pink.lighten(), .pink)
        case .waveform: (.pink.lighten(), .pink)
        case .radioFill: (.purple.lighten(), .purple)
        case .hifispeakerFill: (.purple.lighten(), .purple)
        case .pianokeys: (.white.darken(by: 0.2), .white.darken(by: 0.4))
        case .guitars: (.yellow, .orange)
        case .dial: (.gray, .black.lighten())

        case .forkKnife: (.orange.lighten(), .orange)
        case .cupAndSaucer: (.orange.lighten(), .orange)
        case .wineglass: (.red.darken(by: 0.5), .red.darken(by: 0.7))
        case .cart: (.cyan, .blue)
        case .bagFill: (.cyan, .blue)
        case .tshirt: (.cyan, .blue)
        case .comb: (.pink, .pink.darken())
        case .pawprint: (.brown.lighten(), .brown)
        case .leaf: (.green, .green.darken())
        case .tree: (.green, .brown)

        case .briefcase: (.brown.lighten(), .brown.darken())
        case .dollarsignCircle: (.orange.lighten(), .orange.darken())
        case .chartLineUptrend: (.blue.darken(by: 0.6), .blue.darken(by: 0.8))
        case .building2: (.gray, .gray.darken())
        case .banknote: (.green.lighten(), .green.darken())
        case .creditcard: (.orange, .red)
        case .docText: (.cyan, .cyan.darken())
        case .envelope: (.cyan, .blue)
        case .phone: (.green.lighten(), .green)
        case .signature: (.green.darken(by: 0.5), .green.darken(by: 0.65))

        case .graduationcap: (.black.lighten(by: 0.3), .black.lighten(by: 0.1))
        case .booksVertical: (.orange.lighten(), .orange.darken())
        case .textBookClosed: (.orange.lighten(), .orange.darken())
        case .characterBubble: (.yellow, .orange)
        case .globe2: (.blue, .green.darken())
        case .buildingColumns: (.gray, .gray.darken())
        case .scroll: (.yellow.darken(by: 0.1), .brown)
        case .puzzlepiece: (.orange, .pink)
        case .lightbulb: (.yellow, .yellow.darken())
        case .brain: (.pink.lighten(), .red)

        case .airplane: (.orange, .orange.darken())
        case .car: (.gray.darken(), .black.lighten())
        case .bus: (.gray.darken(), .black.lighten())
        case .ferry: (.gray.darken(), .black.lighten())
        case .mappin: (.pink, .red)
        case .map: (.beige, .beige.darken())
        case .mountain: (.green.lighten(by: 0.3), .green.lighten(by: 0.1))
        case .house: (.yellow, .orange)
        case .tent: (.yellow, .orange)
        case .beach: (.cyan, .cyan.darken())

        case .heart: (.magenta, .pink)
        case .star: (.orange.lighten(), .orange)
        case .paintbrush: (.indigo.lighten(), .indigo)
        case .wrench: (.gray, .gray.darken())
        case .gamecontroller: (.purple, .pink)
        case .photo: (.blue, .indigo)
        case .handThumbsup: (.yellow, .orange)
        case .faceSmilingFill: (.yellow, .orange)
        case .personFill: (.cyan, .blue)
        case .person2Fill: (.cyan, .blue)
        }
    }

    var gradient: LinearGradient {
        let pair = gradientColors
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Returns the gradient for the icon name stored on a `FeedList`,
    /// falling back to `Color.accentColor` if the raw value is unknown.
    static func gradient(forRawValue rawValue: String) -> AnyShapeStyle {
        if let icon = ListIcon(rawValue: rawValue) {
            return AnyShapeStyle(icon.gradient)
        }
        return AnyShapeStyle(Color.accentColor)
    }
}
