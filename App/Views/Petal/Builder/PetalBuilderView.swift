import SwiftUI

/// Selector-based recipe editor for a single Web Feed.
struct PetalBuilderView: View {

    enum Mode {
        case create(initialURL: String)
        case edit(feed: Feed, recipe: PetalRecipe)
    }

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var recipe = PetalRecipe(name: "", siteURL: "", itemSelector: "")
    @State private var fetchedHTML: String?
    @State private var previewArticles: [ParsedArticle] = []
    @State private var isFetching = false
    @State private var errorMessage: String?
    @State private var previewTask: Task<Void, Never>?
    @State private var showDeleteConfirm = false
    @State private var showElementPicker = false
    @State private var hasInitialized = false

    var body: some View {
        NavigationStack {
            Form {
                PetalBuilderSourceSection(
                    name: $recipe.name,
                    siteURL: $recipe.siteURL,
                    fetchMode: $recipe.fetchMode
                )
                PetalBuilderSelectorsSection(
                    recipe: $recipe,
                    canAutoDetect: fetchedHTML != nil && !isFetching,
                    isFetching: isFetching,
                    onAutoDetect: runAutoDetect,
                    onFetch: { Task { await fetchAndPreview(force: true) } },
                    onSelectorChanged: schedulePreview,
                    onPickElements: { showElementPicker = true }
                )
                PetalBuilderPreviewSection(
                    articles: previewArticles,
                    errorMessage: errorMessage,
                    isFetching: isFetching,
                    hasFetchedHTML: fetchedHTML != nil
                )
                if case .edit = mode {
                    Section {
                        Button(String(localized: "Builder.Delete", table: "Petal"), role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .animation(.smooth.speed(2.0), value: previewArticles.count)
            .animation(.smooth.speed(2.0), value: isFetching)
            .sheet(isPresented: $showElementPicker, onDismiss: schedulePreview) {
                if let html = fetchedHTML {
                    PetalElementPickerView(recipe: $recipe, html: html)
                }
            }
            .navigationTitle(String(localized: "Builder.Title", table: "Petal"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { save() }
                        .disabled(!canSave)
                }
            }
            .alert(String(localized: "Builder.DeleteConfirm.Title", table: "Petal"),
                   isPresented: $showDeleteConfirm) {
                Button(String(localized: "Builder.Delete", table: "Petal"), role: .destructive) {
                    deletePetal()
                }
                Button("Shared.Cancel", role: .cancel) {}
            } message: {
                Text(String(localized: "Builder.DeleteConfirm.Message", table: "Petal"))
            }
            .onAppear {
                if !hasInitialized {
                    hasInitialized = true
                    switch mode {
                    case .create(let initialURL):
                        recipe = PetalRecipe(name: "", siteURL: initialURL, itemSelector: "")
                    case .edit(_, let existingRecipe):
                        recipe = existingRecipe
                    }
                }
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
            ? String(localized: "Error.NoMatches", table: "Petal") : nil
    }

    /// Runs the heuristic selector finder against cached HTML and folds suggestions into the recipe.
    private func runAutoDetect() {
        guard let html = fetchedHTML else { return }
        guard let suggestion = PetalAutoDetect.detect(
            html: html, siteURL: recipe.siteURL
        ) else {
            errorMessage = String(localized: "Builder.AutoDetect.Failed", table: "Petal")
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
        if let id = PetalStore.shared.recipe(forFeedURL: feed.url)?.id {
            try? PetalStore.shared.deleteRecipe(id: id)
        }
        dismiss()
    }
}
