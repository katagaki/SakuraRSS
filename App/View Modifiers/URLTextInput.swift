import SwiftUI

extension View {

    /// Settings for a field that takes a web address. macOS has no keyboard
    /// or capitalization hints to give, so only autocorrection is turned off.
    func urlTextInput() -> some View {
        #if os(macOS)
        autocorrectionDisabled()
        #else
        textContentType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        #endif
    }
}
