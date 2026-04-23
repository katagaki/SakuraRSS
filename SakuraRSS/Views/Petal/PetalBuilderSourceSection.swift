import SwiftUI

/// "Source" section of the Web Feed builder: name, URL, and fetch mode.
struct PetalBuilderSourceSection: View {

    @Binding var name: String
    @Binding var siteURL: String
    @Binding var fetchMode: PetalRecipe.FetchMode

    var body: some View {
        Section {
            TextField(String(localized: "Builder.Name.Placeholder", table: "Petal"), text: $name)
                .textInputAutocapitalization(.words)
            TextField(String(localized: "Builder.URL.Placeholder", table: "Petal"), text: $siteURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Picker(String(localized: "Builder.FetchMode", table: "Petal"), selection: $fetchMode) {
                Text(String(localized: "Builder.FetchMode.Static", table: "Petal"))
                    .tag(PetalRecipe.FetchMode.staticHTML)
                Text(String(localized: "Builder.FetchMode.Rendered", table: "Petal"))
                    .tag(PetalRecipe.FetchMode.rendered)
            }
        } header: {
            Text(String(localized: "Builder.Section.Source", table: "Petal"))
        } footer: {
            Text(String(localized: "Builder.Section.SourceFooter", table: "Petal"))
        }
    }
}
