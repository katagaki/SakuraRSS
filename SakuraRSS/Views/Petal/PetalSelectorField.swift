import SwiftUI

/// A tiny labelled monospaced text field used by the selectors
/// section of the Web Feed builder.
///
/// Extracted so each selector row is one call to this view rather
/// than three lines of layout repeated six times.  Keeping it
/// separate also makes it easy to tweak the field styling (font,
/// autocap, autocorrect) in one place later.
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

    /// Convenience initializer for recipe fields that are
    /// `String?`.  The builder treats an empty string as "no
    /// selector" so the engine falls back to its defaults; this
    /// initializer folds that convention into a single
    /// construction call.
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
