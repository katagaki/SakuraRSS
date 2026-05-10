import SwiftUI
import Hanami

/// Watches a search-field text binding for `/enable-feature:KEY` and
/// `/disable-feature:KEY` inputs. When the input matches a known
/// `FeatureFlag`, applies the change via `FeatureFlagStore.shared` and
/// clears the binding so a normal search isn't run.
struct FeatureCommandHandlerModifier: ViewModifier {

    @Binding var searchText: String

    func body(content: Content) -> some View {
        content.onChange(of: searchText) { _, newValue in
            guard !newValue.isEmpty else { return }
            if FeatureFlagStore.shared.handle(searchInput: newValue) {
                searchText = ""
            }
        }
    }
}

extension View {
    func handleFeatureCommands(searchText: Binding<String>) -> some View {
        modifier(FeatureCommandHandlerModifier(searchText: searchText))
    }
}
