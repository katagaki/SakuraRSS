import AppKit

@MainActor
enum IPhoneSpreads {
    /// The hardware's center on the canvas.
    static let center = NSPoint(x: 642, y: 1550)
    static let width: CGFloat = 1095

    static func single(_ panel: Panel, rawName: String) -> Spread {
        Spread(
            device: .iPhone,
            panels: [panel],
            placements: [Placement(screen: .capture(rawName), center: center, width: width)]
        )
    }

    static let all: [Spread] = [
        Spread(
            device: .iPhone,
            panels: [Panel(
                outName: "01-more-than-rss",
                copy: [
                    "en": Copy(header: "More than just RSS", caption: "Simple, yet familiar"),
                    "ja": Copy(header: "RSSを超えたRSS", caption: "シンプルで使いやすい")
                ],
                gradient: Palette.lavender
            )],
            placements: [
                Placement(screen: .capture("01-following.png"), center: NSPoint(x: 6, y: 1550), width: width),
                Placement(screen: .capture("01-today.png"), center: NSPoint(x: 1161, y: 1550), width: width)
            ]
        ),
        single(Panel(
            outName: "02-follow",
            copy: [
                "en": Copy(header: "Follow and organize", caption: "Organize feeds into lists"),
                "ja": Copy(header: "フォローするだけ", caption: "リストでの管理にも対応")
            ],
            gradient: Palette.lavender
        ), rawName: "02-feeds.png"),
        single(Panel(
            outName: "03-reader",
            copy: [
                "en": Copy(header: "Read in peace", caption: "No ads, just text"),
                "ja": Copy(header: "爽やかなリーダー", caption: "広告なしで、記事だけ読める")
            ],
            gradient: Palette.lavender
        ), rawName: "03-reader.png"),
        single(Panel(
            outName: "04-bookmarks",
            copy: [
                "en": Copy(header: "Bookmark anything", caption: "For when you need to remember"),
                "ja": Copy(header: "なんでもブックマーク", caption: "今じゃないならあとで読もう")
            ],
            gradient: Palette.lavender
        ), rawName: "04-bookmarks.png"),
        single(Panel(
            outName: "05-discover",
            copy: [
                "en": Copy(header: "Discover topics", caption: "Search and find similar content"),
                "ja": Copy(header: "話題を発見", caption: "キーワードで全記事を検索")
            ],
            gradient: Palette.lavender
        ), rawName: "05-discover.png"),
        single(Panel(
            outName: "06-videos",
            copy: [
                "en": Copy(header: "Discover videos", caption: "Follow YouTube and Vimeo feeds"),
                "ja": Copy(header: "動画を発見", caption: "YouTubeやニコニコ動画をフォロー")
            ],
            gradient: Palette.blossom
        ), rawName: "06-videos.png"),
        single(Panel(
            outName: "07-podcasts",
            copy: [
                "en": Copy(header: "Discover audio", caption: "Follow podcast feeds"),
                "ja": Copy(header: "ポッドキャストを発見", caption: "通勤中でも聞いて色々と学べる")
            ],
            gradient: Palette.meadow
        ), rawName: "07-podcasts.png"),
        single(Panel(
            outName: "08-visuals",
            copy: [
                "en": Copy(header: "Discover rich visuals", caption: "Put images front and center"),
                "ja": Copy(header: "ビジュアルを発見", caption: "記事の画像を中心に閲覧できる")
            ],
            gradient: Palette.sunset
        ), rawName: "08-visuals.png"),
        single(Panel(
            outName: "09-headlines",
            copy: [
                "en": Copy(header: "Discover headlines", caption: "Read, swipe, repeat"),
                "ja": Copy(header: "ヘッドラインを発見", caption: "目を通す。スワイプ。繰り返す。")
            ],
            gradient: Palette.sunrise
        ), rawName: "09-headlines.png"),
        single(Panel(
            outName: "10-incidents",
            copy: [
                "en": Copy(header: "Discover incidents", caption: "Is it down at the moment?"),
                "ja": Copy(header: "インシデントを発見", caption: "今ダウンしている？")
            ],
            gradient: Palette.alert
        ), rawName: "10-incidents.png"),
        single(Panel(
            outName: "99-tabs",
            copy: [
                "en": Copy(header: "Browse in tabs", caption: "Keep everything you're reading open"),
                "ja": Copy(header: "タブで読む", caption: "読みかけのコンテンツを開いたままに")
            ],
            gradient: Palette.lavender
        ), rawName: "99-tabs.png")
    ]
}
