import SwiftUI

extension ToolbarItemPlacement {

    /// A sheet's cancel position: the top bar's leading edge on iOS, the
    /// cancellation slot on macOS, which has no top bar placements.
    static var sheetLeading: ToolbarItemPlacement {
        #if os(macOS)
        .cancellationAction
        #else
        .topBarLeading
        #endif
    }

    /// A sheet's confirm position: the top bar's trailing edge on iOS, the
    /// confirmation slot on macOS.
    static var sheetTrailing: ToolbarItemPlacement {
        #if os(macOS)
        .confirmationAction
        #else
        .topBarTrailing
        #endif
    }

    /// A sheet's close position: the top bar's trailing edge on iOS, the
    /// cancellation slot on macOS so that Escape closes the sheet.
    static var sheetClose: ToolbarItemPlacement {
        #if os(macOS)
        .cancellationAction
        #else
        .topBarTrailing
        #endif
    }

    /// Trailing controls that aren't the sheet's confirm action, which macOS
    /// would otherwise bind to Return.
    static var sheetTrailingAccessory: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }
}

extension View {

    /// An inline navigation title on iOS; macOS has no large titles to opt
    /// out of.
    func inlineNavigationTitle() -> some View {
        #if os(macOS)
        self
        #else
        navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
