import Foundation

nonisolated enum ListIcon: String, CaseIterable, Identifiable, Sendable {
    // News categories
    case newspaper
    case bookClosed = "book.closed"
    case globe
    case megaphone
    case exclamationmarkTriangle = "exclamationmark.triangle"
    case flame
    case bolt
    case eyeglasses
    case magnifyingglass
    case textQuote = "text.quote"

    // Technology & science
    case laptopcomputer
    case iphone
    case serverRack = "server.rack"
    case cpu
    case wifi
    case antenna = "antenna.radiowaves.left.and.right"
    case atom
    case flask = "flask.fill"
    case stethoscope
    case cross = "cross.case"

    // Sports & fitness
    case sportscourt
    case figureRun = "figure.run"
    case soccerball
    case basketball
    case football = "football.fill"
    case tennisRacket = "tennis.racket"
    case trophy
    case medal = "medal.fill"
    case bicycle
    case dumbbell

    // Entertainment & video
    case film
    case tv
    case playRectangle = "play.rectangle"
    case theatermasks = "theatermasks.fill"
    case popcorn
    case camera
    case videoCamera = "video.fill"
    case rectangleOnRectangle = "rectangle.on.rectangle"
    case sparkles
    case wand = "wand.and.stars"

    // Music & podcasts
    case musicNote = "music.note"
    case musicMic = "music.mic"
    case headphones
    case micFill = "mic.fill"
    case waveform
    case radioFill = "radio.fill"
    case hifispeakerFill = "hifispeaker.fill"
    case pianokeys
    case guitars = "guitars.fill"
    case dial = "dial.medium.fill"

    // Food & lifestyle
    case forkKnife = "fork.knife"
    case cupAndSaucer = "cup.and.saucer.fill"
    case wineglass
    case cart
    case bagFill = "bag.fill"
    case tshirt
    case comb
    case pawprint
    case leaf
    case tree

    // Business & finance
    case briefcase
    case dollarsignCircle = "dollarsign.circle"
    case chartLineUptrend = "chart.line.uptrend.xyaxis"
    case building2 = "building.2"
    case banknote
    case creditcard
    case docText = "doc.text"
    case envelope
    case phone
    case signature

    // Education & culture
    case graduationcap
    case booksVertical = "books.vertical"
    case textBookClosed = "text.book.closed"
    case characterBubble = "character.bubble"
    case globe2 = "globe.americas"
    case buildingColumns = "building.columns"
    case scroll
    case puzzlepiece
    case lightbulb
    case brain

    // Travel & places
    case airplane
    case car
    case bus
    case ferry = "ferry.fill"
    case mappin
    case map
    case mountain = "mountain.2"
    case house
    case tent
    case beach = "beach.umbrella"

    // General
    case heart
    case star
    case paintbrush
    case wrench
    case gamecontroller
    case photo
    case handThumbsup = "hand.thumbsup"
    case faceSmilingFill = "face.smiling.fill"
    case personFill = "person.fill"
    case person2Fill = "person.2.fill"

    var id: String { rawValue }
}
