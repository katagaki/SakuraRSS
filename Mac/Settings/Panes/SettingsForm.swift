import SwiftUI

/// A settings pane laid out like Safari's: labels right-aligned in a column,
/// controls beside them. A plain stack rather than a `Form`, which scrolls and
/// so can't report the height the window needs to fit it.
struct SettingsForm<Content: View>: View {

    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .labeledContentStyle(SettingsColumnStyle())
        .toggleStyle(.checkbox)
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(width: 640, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One settings row: the label right-aligned in a fixed column, so every
/// row's controls start on the same line.
struct SettingsColumnStyle: LabeledContentStyle {

    static let labelWidth: CGFloat = 220

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.label
                .multilineTextAlignment(.trailing)
                .frame(width: Self.labelWidth, alignment: .trailing)
            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Small explanatory text under a control, as Safari puts its notes.
struct SettingsNote: View {

    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 360, alignment: .leading)
    }
}

/// Extra space between groups of rows, where Safari leaves a gap.
struct SettingsGroupSpacer: View {

    var body: some View {
        Color.clear.frame(height: 6)
    }
}

/// A pop-up menu row: its title in the label column, the menu beside it.
struct SettingsPicker<Value: Hashable, Options: View>: View {

    let title: String
    @Binding var selection: Value
    @ViewBuilder let options: () -> Options

    init(_ title: String, selection: Binding<Value>, @ViewBuilder options: @escaping () -> Options) {
        self.title = title
        self._selection = selection
        self.options = options
    }

    var body: some View {
        LabeledContent(title) {
            Picker(title, selection: $selection, content: options)
                .labelsHidden()
                .fixedSize()
        }
    }
}
