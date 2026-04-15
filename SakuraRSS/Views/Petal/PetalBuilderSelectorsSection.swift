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
    let onAutoDetect: () -> Void
    let onSelectorChanged: () -> Void

    var body: some View {
        Section {
            Button {
                onAutoDetect()
            } label: {
                Label("WebFeed.Builder.AutoDetect",
                      systemImage: "wand.and.stars")
            }
            .disabled(!canAutoDetect)

            PetalSelectorField(
                label: "Petal.Builder.ItemSelector",
                text: $recipe.itemSelector,
                placeholder: "article, li.post, [data-testid=card]"
            )
            PetalSelectorField(
                label: "Petal.Builder.TitleSelector",
                optional: $recipe.titleSelector,
                placeholder: "h2, .title"
            )
            PetalSelectorField(
                label: "Petal.Builder.LinkSelector",
                optional: $recipe.linkSelector,
                placeholder: "a, a.post-link"
            )
            PetalSelectorField(
                label: "Petal.Builder.SummarySelector",
                optional: $recipe.summarySelector,
                placeholder: "p.excerpt, .summary"
            )
            PetalSelectorField(
                label: "Petal.Builder.ImageSelector",
                optional: $recipe.imageSelector,
                placeholder: "img, .hero img"
            )
            PetalSelectorField(
                label: "Petal.Builder.DateSelector",
                optional: $recipe.dateSelector,
                placeholder: "time, .published"
            )
        } header: {
            Text("Petal.Builder.Section.Selectors")
        } footer: {
            Text("Petal.Builder.Section.SelectorsFooter")
        }
        .onChange(of: recipe.itemSelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.titleSelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.linkSelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.summarySelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.imageSelector) { _, _ in onSelectorChanged() }
        .onChange(of: recipe.dateSelector) { _, _ in onSelectorChanged() }
    }
}
