import AppIntents

enum SingleFeedWidgetLayout: String, AppEnum {
    case text
    case thumbnails

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "SingleFeedWidget.Layout")
    }

    static var caseDisplayRepresentations: [SingleFeedWidgetLayout: DisplayRepresentation] {
        [
            .text: DisplayRepresentation(title: "SingleFeedWidget.Layout.Text"),
            .thumbnails: DisplayRepresentation(title: "SingleFeedWidget.Layout.Thumbnails")
        ]
    }
}
