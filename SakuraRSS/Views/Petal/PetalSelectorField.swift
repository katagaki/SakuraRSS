import SwiftUI

/// Labelled monospaced text field used by the Web Feed builder's selector rows.
struct PetalSelectorField: View {

    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}

extension PetalSelectorField {

    /// Convenience initializer for optional fields; empty string is treated as nil.
    init(
        label: String,
        optional binding: Binding<String?>,
        placeholder: String
    ) {
        self.label = label
        self._text = Binding(
            get: { binding.wrappedValue ?? "" },
            set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }
        )
        self.placeholder = placeholder
    }
}
