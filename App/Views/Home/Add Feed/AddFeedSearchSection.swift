import SwiftUI

struct AddFeedSearchSection: View {

    @Binding var urlInput: String
    var isSearching: Bool
    var isURLFieldFocused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sakura"
    }

    var body: some View {
        Section {
            TextField(String(localized: "AddFeed.DomainPlaceholder", table: "Feeds"), text: $urlInput)
                .focused(isURLFieldFocused)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { onSubmit() }
                .overlay(alignment: .trailing) {
                    if urlInput.isEmpty {
                        PasteButton(payloadType: URL.self) { urls in
                            if let url = urls.first {
                                urlInput = url.absoluteString
                            }
                        }
                        .buttonBorderShape(.capsule)
                        .controlSize(.mini)
                    }
                }

            Button {
                onSubmit()
            } label: {
                HStack {
                    Text(String(localized: "AddFeed.Search", table: "Feeds"))
                    if isSearching {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(urlInput.isEmpty || isSearching)
        } header: {
            Text(String(localized: "AddFeed.Section.Search", table: "Feeds"))
        } footer: {
            Text(String(localized: "AddFeed.Section.SearchFooter.\(appName)", table: "Feeds"))
        }
    }
}
