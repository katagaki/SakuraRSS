import AppIntents

enum SingleFeedWidgetLayout: String, AppEnum {
    case text
    case thumbnails

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("SingleFeedWidget.Layout", table: "Widget"))
    }

    static var caseDisplayRepresentations: [SingleFeedWidgetLayout: DisplayRepresentation] {
        [
            .text: DisplayRepresentation(title: LocalizedStringResource("SingleFeedWidget.Layout.Text", table: "Widget")),
            .thumbnails: DisplayRepresentation(title: LocalizedStringResource("SingleFeedWidget.Layout.Thumbnails", table: "Widget"))
        ]
    }
}

enum SingleFeedWidgetColumns: Int, AppEnum {
    case two = 2
    case three = 3

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("SingleFeedWidget.Columns", table: "Widget"))
    }

    static var caseDisplayRepresentations: [SingleFeedWidgetColumns: DisplayRepresentation] {
        [
            .two: DisplayRepresentation(title: LocalizedStringResource("SingleFeedWidget.Columns.Two", table: "Widget")),
            .three: DisplayRepresentation(title: LocalizedStringResource("SingleFeedWidget.Columns.Three", table: "Widget"))
        ]
    }
}
