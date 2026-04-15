import SwiftUI

/// Selector-based recipe editor for a single Petal.
///
/// The view keeps things approachable for users who've never heard of
/// CSS selectors:
///
/// 1. They paste a URL and tap **Fetch**.
/// 2. The builder loads the page and shows a live preview of every
///    item that currently matches `itemSelector`.
/// 3. Each selector field has an info button explaining what it does
///    and a sensible default.
/// 4. Saving calls `FeedManager.addPetalFeed` (create) or
///    `updatePetalRecipe` (edit), which re-routes the refresh to
///    `PetalEngine`.
///
/// The preview re-runs on a debounced basis so heavy typing doesn't
/// hammer the network; fetches are cached so tweaking selectors
/// after an initial fetch is instantaneous.
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
                sourceSection
                selectorsSection
                previewSection
                if case .edit = mode {
                    deleteSection
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
                if case .create = mode, !recipe.siteURL.isEmpty {
                    Task { await fetchAndPreview() }
                } else if case .edit = mode, !recipe.siteURL.isEmpty {
                    Task { await fetchAndPreview() }
                }
            }
            .onDisappear {
                previewTask?.cancel()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sourceSection: some View {
        Section {
            TextField("Petal.Builder.Name.Placeholder", text: $recipe.name)
                .textInputAutocapitalization(.words)
            TextField("Petal.Builder.URL.Placeholder", text: $recipe.siteURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Picker("Petal.Builder.FetchMode", selection: $recipe.fetchMode) {
                Text("Petal.Builder.FetchMode.Static")
                    .tag(PetalRecipe.FetchMode.staticHTML)
                Text("Petal.Builder.FetchMode.Rendered")
                    .tag(PetalRecipe.FetchMode.rendered)
            }
            Button {
                Task { await fetchAndPreview(force: true) }
            } label: {
                HStack {
                    Text("Petal.Builder.Fetch")
                    if isFetching {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(recipe.siteURL.isEmpty || isFetching)
        } header: {
            Text("Petal.Builder.Section.Source")
        } footer: {
            Text("Petal.Builder.Section.SourceFooter")
        }
    }

    @ViewBuilder
    private var selectorsSection: some View {
        Section {
            selectorField(
                label: "Petal.Builder.ItemSelector",
                text: $recipe.itemSelector,
                placeholder: "article, li.post, [data-testid=card]"
            )
            selectorField(
                label: "Petal.Builder.TitleSelector",
                text: Binding(
                    get: { recipe.titleSelector ?? "" },
                    set: { recipe.titleSelector = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "h2, .title"
            )
            selectorField(
                label: "Petal.Builder.LinkSelector",
                text: Binding(
                    get: { recipe.linkSelector ?? "" },
                    set: { recipe.linkSelector = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "a, a.post-link"
            )
            selectorField(
                label: "Petal.Builder.SummarySelector",
                text: Binding(
                    get: { recipe.summarySelector ?? "" },
                    set: { recipe.summarySelector = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "p.excerpt, .summary"
            )
            selectorField(
                label: "Petal.Builder.ImageSelector",
                text: Binding(
                    get: { recipe.imageSelector ?? "" },
                    set: { recipe.imageSelector = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "img, .hero img"
            )
            selectorField(
                label: "Petal.Builder.DateSelector",
                text: Binding(
                    get: { recipe.dateSelector ?? "" },
                    set: { recipe.dateSelector = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "time, .published"
            )
        } header: {
            Text("Petal.Builder.Section.Selectors")
        } footer: {
            Text("Petal.Builder.Section.SelectorsFooter")
        }
        .onChange(of: recipe.itemSelector) { _, _ in schedulePreview() }
        .onChange(of: recipe.titleSelector) { _, _ in schedulePreview() }
        .onChange(of: recipe.linkSelector) { _, _ in schedulePreview() }
        .onChange(of: recipe.summarySelector) { _, _ in schedulePreview() }
        .onChange(of: recipe.imageSelector) { _, _ in schedulePreview() }
        .onChange(of: recipe.dateSelector) { _, _ in schedulePreview() }
    }

    @ViewBuilder
    private var previewSection: some View {
        Section {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if previewArticles.isEmpty && !isFetching && fetchedHTML != nil {
                Text("Petal.Builder.Preview.Empty")
                    .foregroundStyle(.secondary)
            } else if previewArticles.isEmpty && fetchedHTML == nil {
                Text("Petal.Builder.Preview.TapFetch")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(previewArticles.prefix(20), id: \.url) { article in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.body)
                            .lineLimit(2)
                        Text(article.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let summary = article.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            HStack {
                Text("Petal.Builder.Section.Preview")
                if !previewArticles.isEmpty {
                    Spacer()
                    Text("\(previewArticles.count)")
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button("Petal.Builder.Delete", role: .destructive) {
                showDeleteConfirm = true
            }
        }
    }

    // MARK: - Helpers

    private func selectorField(
        label: LocalizedStringKey,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

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
