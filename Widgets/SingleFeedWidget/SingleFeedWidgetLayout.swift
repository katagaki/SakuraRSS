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

enum SingleFeedWidgetColumns: Int, AppEnum {
    case two = 2
    case three = 3

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "SingleFeedWidget.Columns")
    }

    static var caseDisplayRepresentations: [SingleFeedWidgetColumns: DisplayRepresentation] {
        [
            .two: DisplayRepresentation(title: "SingleFeedWidget.Columns.Two"),
            .three: DisplayRepresentation(title: "SingleFeedWidget.Columns.Three")
        ]
    }
}
