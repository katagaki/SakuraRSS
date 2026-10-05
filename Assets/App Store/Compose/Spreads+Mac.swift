import AppKit

@MainActor
enum MacSpreads {
    /// The MacBook's center on the canvas. It runs off the bottom and both sides.
    static let center = NSPoint(x: 1440, y: 1281)
    static let width: CGFloat = 3207

    static let all: [Spread] = [
        Spread(
            device: .mac,
            panels: [Panel(
                outName: "01-more-than-rss",
                copy: [
                    "en": Copy(header: "More than just RSS"),
                    "ja": Copy(header: "RSS だけではありません")
                ],
                gradient: Palette.lavender
            )],
            placements: [
                Placement(
                    screen: .desktop(wallpaper: "wallpaper.jpg", windows: [
                        Window(rawName: "01-window.png", center: .zero)
                    ]),
                    center: center, width: width
                )
            ]
        ),
        Spread(
            device: .mac,
            panels: [Panel(
                outName: "02-media",
                copy: [
                    "en": Copy(header: "Read, watch, listen your way"),
                    "ja": Copy(header: "動画を見る・ポッドキャストを聴く・記事を読む")
                ],
                gradient: Palette.lavender
            )],
            placements: [
                Placement(
                    screen: .desktop(wallpaper: "wallpaper.jpg", windows: [
                        Window(rawName: "02-top-left.png", center: NSPoint(x: -617, y: -349), scale: 0.5),
                        Window(rawName: "02-top-right.png", center: NSPoint(x: 618, y: -349), scale: 0.5),
                        Window(rawName: "02-bottom-left.png", center: NSPoint(x: -618, y: 392), scale: 0.5),
                        Window(rawName: "02-bottom-right.png", center: NSPoint(x: 618, y: 392), scale: 0.5)
                    ]),
                    center: center, width: width
                )
            ]
        )
    ]
}
