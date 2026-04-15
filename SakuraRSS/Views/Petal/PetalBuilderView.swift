import SwiftUI

/// Selector-based recipe editor for a single Web Feed.
///
/// The view keeps things approachable for users who've never
/// heard of CSS selectors:
///
/// 1. They paste a URL and tap **Fetch**.
/// 2. The builder loads the page and shows a live preview of
///    every item that currently matches `itemSelector`.
/// 3. **Auto-Detect** runs a heuristic pattern finder that tries
///    to guess the right selectors for them.
/// 4. Saving calls `FeedManager.addPetalFeed` (create) or
///    `updatePetalRecipe` (edit), which re-routes the refresh to
///    `PetalEngine`.
///
/// The preview re-runs on a debounced basis so heavy typing
/// doesn't hammer the network; fetches are cached so tweaking
/// selectors after an initial fetch is instantaneous.
///
/// This view owns the state and action methods; the three form
/// sections (source, selectors, preview) live in their own
/// sibling files so each is small enough to read in one screen.
struct PetalBuilderView: View {

    enum Mode {
        case create(initialURL: String)
        case edit(feed: Feed, recipe: PetalRecipe)
    }

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var recipe: PetalRecipe
    @State private var fetchedHTML: String?
    @State private var previewArticles: [ParsedArticle] = []
    @State private var isFetching = false
    @State private var errorMessage: String?
    @State private var previewTask: Task<Void, Never>?
    @State private var showDeleteConfirm = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let initialURL):
            _recipe = State(initialValue: PetalRecipe(
                name: "",
                siteURL: initialURL,
                itemSelector: "article"
            ))
        case .edit(_, let recipe):
            _recipe = State(initialValue: recipe)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                PetalBuilderSourceSection(
                    name: $recipe.name,
                    siteURL: $recipe.siteURL,
                    fetchMode: $recipe.fetchMode,
                    isFetching: isFetching,
                    onFetch: { Task { await fetchAndPreview(force: true) } }
                )
                PetalBuilderSelectorsSection(
                    recipe: $recipe,
                    canAutoDetect: fetchedHTML != nil && !isFetching,
                    onAutoDetect: runAutoDetect,
                    onSelectorChanged: schedulePreview
                )
                PetalBuilderPreviewSection(
                    articles: previewArticles,
                    errorMessage: errorMessage,
                    isFetching: isFetching,
                    hasFetchedHTML: fetchedHTML != nil
                )
                if case .edit = mode {
                    Section {
                        Button("Petal.Builder.Delete", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .animation(.smooth.speed(2.0), value: previewArticles.count)
            .animation(.smooth.speed(2.0), value: isFetching)
            .navigationTitle("Petal.Builder.Title")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Shared.Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Shared.Done") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Petal.Builder.DeleteConfirm.Title",
                   isPresented: $showDeleteConfirm) {
                Button("Petal.Builder.Delete", role: .destructive) {
                    deletePetal()
                }
                Button("Shared.Cancel", role: .cancel) {}
            } message: {
                Text("Petal.Builder.DeleteConfirm.Message")
            }
            .onAppear {
                if !recipe.siteURL.isEmpty {
                    Task { await fetchAndPreview() }
                }
            }
            .onDisappear {
                previewTask?.cancel()
            }
        }
    }

    // MARK: - Derived state

    private var canSave: Bool {
        !recipe.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !recipe.siteURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !recipe.itemSelector.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Fetch & Preview

    private func fetchAndPreview(force: Bool = false) async {
        if !force, fetchedHTML != nil {
            runPreviewFromCache()
            return
        }
        await MainActor.run {
            isFetching = true
            errorMessage = nil
        }
        let result = await PetalEngine.preview(for: recipe)
        await MainActor.run {
            isFetching = false
            fetchedHTML = result.fetchedHTMLSample
            previewArticles = result.articles
            errorMessage = result.errorMessage
        }
    }

    private func schedulePreview() {
        previewTask?.cancel()
        // Only run the in-memory re-parse if we already have HTML.
        guard fetchedHTML != nil else { return }
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run { runPreviewFromCache() }
        }
    }

    private func runPreviewFromCache() {
        guard let html = fetchedHTML else { return }
        previewArticles = PetalEngine.parse(html: html, recipe: recipe)
        errorMessage = previewArticles.isEmpty
            ? String(localized: "Petal.Error.NoMatches") : nil
    }

    /// Runs the heuristic selector finder against the currently
    /// cached HTML and folds its suggestions into the editable
    /// recipe.  Preserves any fields the user has already filled
    /// in (notably `name`, which is usually already set by the
    /// AddFeed flow that seeds the builder with a URL).
    private func runAutoDetect() {
        guard let html = fetchedHTML else { return }
        guard let suggestion = PetalAutoDetect.detect(
            html: html, siteURL: recipe.siteURL
        ) else {
            errorMessage = String(localized: "WebFeed.Builder.AutoDetect.Failed")
            return
        }
        if recipe.name.isEmpty {
            recipe.name = suggestion.name
        }
        recipe.itemSelector = suggestion.itemSelector
        recipe.titleSelector = suggestion.titleSelector
        recipe.linkSelector = suggestion.linkSelector
        recipe.summarySelector = suggestion.summarySelector
        recipe.imageSelector = suggestion.imageSelector
        recipe.dateSelector = suggestion.dateSelector
        recipe.dateAttribute = suggestion.dateAttribute
        errorMessage = nil
        runPreviewFromCache()
    }

    // MARK: - Save / Delete

    private func save() {
        do {
            switch mode {
            case .create:
                _ = try feedManager.addPetalFeed(recipe: recipe)
            case .edit(let feed, _):
                try feedManager.updatePetalRecipe(feed: feed, recipe: recipe)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePetal() {
        guard case .edit(let feed, _) = mode else { return }
        try? feedManager.deleteFeed(feed)
        if let id = PetalRecipe.recipeID(from: feed.url) {
            try? PetalStore.shared.deleteRecipe(id: id)
        }
        dismiss()
    }
}
