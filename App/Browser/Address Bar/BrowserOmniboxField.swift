import SwiftUI

/// The address field as it appears inside the bottom toolbar while editing.
struct BrowserOmniboxField: View {

    let model: BrowserOmniboxModel
    let width: CGFloat
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
        .padding(.horizontal, 8)
        .frame(width: width > 0 ? width : nil)
        .task {
            // The field is created as the toolbar morphs; focusing on the
            // same tick is dropped.
            try? await Task.sleep(for: .milliseconds(80))
            isFocused = true
        }
    }
}
