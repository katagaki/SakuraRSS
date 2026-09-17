import SwiftUI

/// The address field as it appears while editing.
struct BrowserOmniboxField: View {

    let model: BrowserOmniboxModel
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
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .task {
            // The field is created as the bar morphs; focusing on the same
            // tick is dropped.
            try? await Task.sleep(for: .milliseconds(80))
            isFocused = true
        }
    }
}
