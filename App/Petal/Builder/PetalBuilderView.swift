import SwiftUI
import Hanami

/// Selector-based recipe editor for a single Web Feed.
@MainActor
struct PetalBuilderView: View {

    enum Mode {
        case create(initialURL: String)
        case edit(feed: Feed, recipe: PetalRecipe)
    }

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let mode: Mode

    @State var recipe = PetalRecipe(name: "", siteURL: "", itemSelector: "")
    @State var fetchedHTML: String?
    @State var previewArticles: [ParsedArticle] = []
    @State var isFetching = false
    @State var errorMessage: String?
    @State var previewTask: Task<Void, Never>?
    @State private var showDeleteConfirm = false
    @State private var selectedPicker: PickerSelection?
    @State var fetchRequestID = UUID()

    private struct PickerSelection: Identifiable {
        let id = UUID()
        let html: String
    }

    private struct PreviewSource: Equatable {
        let siteURL: String
        let fetchMode: PetalRecipe.FetchMode
    }

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let initialURL):
            _recipe = State(initialValue: PetalRecipe(name: "", siteURL: initialURL, itemSelector: ""))
        case .edit(_, let existingRecipe):
            _recipe = State(initialValue: existingRecipe)
        }
    }

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
                    onPickElements: {
                        if let fetchedHTML {
                            selectedPicker = PickerSelection(html: fetchedHTML)
                        }
                    }
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
            .sheet(item: $selectedPicker, onDismiss: schedulePreview) { selection in
                PetalElementPickerView(recipe: $recipe, html: selection.html)
            }
            .navigationTitle(String(localized: "Builder.Title", table: "Petal"))
            .toolbarTitleDisplayMode(.inline)
            .compatibleSoftScrollEdgeEffectStyle()
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
            .task(id: PreviewSource(siteURL: recipe.siteURL, fetchMode: recipe.fetchMode)) {
                fetchedHTML = nil
                previewArticles = []
                errorMessage = nil
                isFetching = false
                fetchRequestID = UUID()
                guard !recipe.siteURL.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await fetchAndPreview()
            }
            .onDisappear {
                previewTask?.cancel()
            }
        }
    }

}
