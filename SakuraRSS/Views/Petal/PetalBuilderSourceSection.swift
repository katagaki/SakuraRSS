import SwiftUI

/// "Source" section of the Web Feed builder: feed name, page
/// URL, fetch mode picker, and the Fetch & Preview button.
///
/// Owns no state of its own — the parent `PetalBuilderView` holds
/// the recipe and toggles `isFetching`, and passes bindings down.
struct PetalBuilderSourceSection: View {

    @Binding var name: String
    @Binding var siteURL: String
    @Binding var fetchMode: PetalRecipe.FetchMode
    let isFetching: Bool
    let onFetch: () -> Void

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
            Button {
                onFetch()
            } label: {
                HStack {
                    Text(String(localized: "Builder.Fetch", table: "Petal"))
                    if isFetching {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(siteURL.isEmpty || isFetching)
        } header: {
            Text(String(localized: "Builder.Section.Source", table: "Petal"))
        } footer: {
            Text(String(localized: "Builder.Section.SourceFooter", table: "Petal"))
        }
    }
}
