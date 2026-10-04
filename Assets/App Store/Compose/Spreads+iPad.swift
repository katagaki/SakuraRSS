import AppKit

@MainActor
enum IPadSpreads {
    static let all: [Spread] = [
        // The reader runs across the first two screenshots.
        Spread(
            device: .iPad,
            panels: [
                Panel(
                    outName: "01-more-than-rss",
                    copy: [
                        "en": Copy(header: "More than just RSS", caption: "Simple, yet familiar"),
                        "ja": Copy(header: "RSS だけではありません", caption: "シンプルで使いやすい")
                    ],
                    gradient: Palette.lavender
                ),
                Panel(
                    outName: "02-reader",
                    copy: [
                        "en": Copy(header: "Read in peace", caption: "No ads, just text"),
                        "ja": Copy(header: "爽やかなリーダー", caption: "広告なしで、記事だけ集中して読める")
                    ],
                    gradient: Palette.lavender
                )
            ],
            placements: [
                Placement(
                    screen: .capture("01-reader.png"), center: NSPoint(x: 1906, y: 1508),
                    width: 3289, orientation: .landscape
                )
            ]
        ),
        Spread(
            device: .iPad,
            panels: [Panel(
                outName: "03-media",
                copy: [
                    "en": Copy(header: "Discover videos, audio, and more", caption: "Watch, listen, learn"),
                    "ja": Copy(header: "動画、ポッドキャストを発見", caption: "観る、聴くからの学ぶ")
                ],
                gradient: Palette.lavender
            )],
            placements: [
                Placement(
                    screen: .capture("03-videos.png"), center: NSPoint(x: 1172, y: 1143),
                    width: 2262, orientation: .landscape
                ),
                Placement(
                    screen: .capture("03-podcasts.png"), center: NSPoint(x: 880, y: 2351),
                    width: 2262, orientation: .landscape
                )
            ]
        ),
        Spread(
            device: .iPad,
            panels: [Panel(
                outName: "04-widgets",
                copy: [
                    "en": Copy(header: "Read anywhere, no really", caption: "In-app, or on your Home Screen"),
                    "ja": Copy(header: "どこでもヘッドライン", caption: "アプリを開かなくてもホーム画面でさくっとチェック")
                ],
                gradient: Palette.lavender
            )],
            placements: [
                Placement(
                    screen: .capture("04-widgets.png"), center: NSPoint(x: 1700, y: 1508),
                    width: 3289, orientation: .landscape
                )
            ]
        ),
        Spread(
            device: .iPad,
            panels: [Panel(
                outName: "99-tabs",
                copy: [
                    "en": Copy(header: "Browse in tabs", caption: "Keep everything you're reading open"),
                    "ja": Copy(header: "タブで読む", caption: "読みかけのコンテンツを開いたままに")
                ],
                gradient: Palette.lavender
            )],
            placements: [
                Placement(
                    screen: .capture("99-tabs.png"), center: NSPoint(x: 1700, y: 1508),
                    width: 3289, orientation: .landscape
                )
            ]
        )
    ]
}
