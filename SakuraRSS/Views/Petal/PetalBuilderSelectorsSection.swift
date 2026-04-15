import SwiftUI

/// "Selectors" section of the Web Feed builder: the Auto-Detect
/// button plus the six CSS-selector input rows.
///
/// Takes a binding to the whole recipe (rather than individual
/// selector bindings) because every selector field ends up
/// needing the same pattern and passing seven bindings clutters
/// the parent call site.  Preview-refresh scheduling is
/// delegated back via `onSelectorChanged` so this view doesn't
/// have to own a debounce task.
struct PetalBuilderSelectorsSection: View {

    @Binding var recipe: PetalRecipe
    let canAutoDetect: Bool
    let isFetching: Bool
    let onAutoDetect: () -> Void
    let onFetch: () -> Void
    let onSelectorChanged: () -> Void

    var body: some View {
        Section {
            Button {
                onAutoDetect()
            } label: {
                Label(String(localized: "Builder.AutoDetect", table: "Petal"),
                      systemImage: "wand.and.stars")
            }
            .disabled(!canAutoDetect)

            PetalSelectorField(
                label: String(localized: "Builder.ItemSelector", table: "Petal"),
                text: $recipe.itemSelector,
                placeholder: "article, li.post, [data-testid=card]"
            )
            PetalSelectorField(
                label: String(localized: "Builder.TitleSelector", table: "Petal"),
                optional: $recipe.titleSelector,
                placeholder: "h2, .title"
            )
            PetalSelectorField(
                label: String(localized: "Builder.LinkSelector", table: "Petal"),
                optional: $recipe.linkSelector,
                placeholder: "a, a.post-link"
            )
            PetalSelectorField(
                label: String(localized: "Builder.SummarySelector", table: "Petal"),
                optional: $recipe.summarySelector,
                placeholder: "p.excerpt, .summary"
            )
            PetalSelectorField(
                label: String(localized: "Builder.ImageSelector", table: "Petal"),
                optional: $recipe.imageSelector,
                placeholder: "img, .hero img"
            )
            PetalSelectorField(
                label: String(localized: "Builder.DateSelector", table: "Petal"),
                optional: $recipe.dateSelector,
                placeholder: "time, .published"
            )

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
            .disabled(recipe.siteURL.isEmpty || isFetching)
        } header: {
            Text(String(localized: "Builder.Section.Selectors", table: "Petal"))
        } footer: {
            Text(String(localized: "Builder.Section.SelectorsFooter", table: "Petal"))
        }
        .onChange(of: recipe.itemSelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.titleSelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.linkSelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.summarySelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.imageSelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.dateSelector) { _, _ in onSelectorChanged() }
    }
}
