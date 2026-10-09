import SwiftUI

struct SheetDismissAction {

    let handler: @MainActor () -> Void

    @MainActor
    func callAsFunction() {
        handler()
    }
}

extension EnvironmentValues {
    // SwiftUI's dismiss does nothing in hosting controllers that AppKit presents as sheets.
    @Entry var hostedSheetDismissAction: SheetDismissAction?
}

@propertyWrapper
struct SheetDismiss: DynamicProperty {

    @Environment(\.dismiss) private var swiftUIDismiss
    @Environment(\.isPresented) private var isPresentedBySwiftUI
    @Environment(\.hostedSheetDismissAction) private var hostedSheetDismissAction

    @MainActor
    var wrappedValue: SheetDismissAction {
        if !isPresentedBySwiftUI, let hostedSheetDismissAction {
            return hostedSheetDismissAction
        }
        let swiftUIDismiss = swiftUIDismiss
        return SheetDismissAction { swiftUIDismiss() }
    }
}
