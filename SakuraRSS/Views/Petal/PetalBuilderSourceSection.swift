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
            TextField("Petal.Builder.Name.Placeholder", text: $name)
                .textInputAutocapitalization(.words)
            TextField("Petal.Builder.URL.Placeholder", text: $siteURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Picker("Petal.Builder.FetchMode", selection: $fetchMode) {
                Text("Petal.Builder.FetchMode.Static")
                    .tag(PetalRecipe.FetchMode.staticHTML)
                Text("Petal.Builder.FetchMode.Rendered")
                    .tag(PetalRecipe.FetchMode.rendered)
            }
            Button {
                onFetch()
            } label: {
                HStack {
                    Text("Petal.Builder.Fetch")
                    if isFetching {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(siteURL.isEmpty || isFetching)
        } header: {
            Text("Petal.Builder.Section.Source")
        } footer: {
            Text("Petal.Builder.Section.SourceFooter")
        }
    }
}
