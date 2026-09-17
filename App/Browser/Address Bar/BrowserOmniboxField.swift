import SwiftUI

/// The address field as it appears inside the bottom toolbar while editing.
struct BrowserOmniboxField: View {

    let model: BrowserOmniboxModel
    /// Only the page on screen takes the keyboard: the mounted-but-hidden
    /// tabs build this field too, and the last one to focus would win.
    let focusesOnAppear: Bool
    let onSubmit: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField(
                String(localized: "AddressField.Prompt", table: "Browser"),
                text: $model.text
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($isFocused)
            .onSubmit(onSubmit)
        }
        .frame(maxWidth: .infinity)
        .task {
            guard focusesOnAppear else { return }
            // The field is created as the toolbar morphs; focusing on the
            // same tick is dropped.
            try? await Task.sleep(for: .milliseconds(80))
            isFocused = true
        }
    }
}
