import SwiftUI
import UniformTypeIdentifiers

/// Lists every Petal feed the user currently owns and hosts the
/// `.srss` import/export entry points.
///
/// Reached from Profile > Labs > Manage Petals.  Editing a row opens
/// the same `PetalBuilderView` used for creation.
struct PetalManagementView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var selectedRecipe: RecipeSelection?
    @State private var shareItem: PetalShareItem?

    private struct RecipeSelection: Identifiable {
        let id: UUID
        let feed: Feed
        let recipe: PetalRecipe
    }

    private struct PetalShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        List {
            Section {
                Text(String(localized: "About.Body", table: "Petal"))
            } header: {
                Text(String(localized: "About.Header", table: "Petal"))
            }

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label(String(localized: "Manage.Import", table: "Petal"), systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text(String(localized: "Manage.ImportFooter", table: "Petal"))
            }

            if petalFeeds.isEmpty {
                Section {
                    Text(String(localized: "Manage.Empty", table: "Petal"))
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(petalFeeds, id: \.id) { feed in
                        row(for: feed)
                    }
                } header: {
                    Text(String(localized: "Manage.Section.Installed", table: "Petal"))
                }
            }
        }
        .navigationTitle(String(localized: "Manage.Title", table: "Petal"))
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [PetalPackage.contentType],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .sheet(item: $selectedRecipe) { selection in
            PetalBuilderView(mode: .edit(feed: selection.feed, recipe: selection.recipe))
                .environment(feedManager)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert(String(localized: "Error.Title", table: "Petal"), isPresented: $showImportError) {
            Button("Shared.OK") {}
        } message: {
            if let importError {
                Text(importError)
            }
        }
    }

    private var petalFeeds: [Feed] {
        feedManager.feeds
            .filter { PetalRecipe.isPetalFeedURL($0.url) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func row(for feed: Feed) -> some View {
        Button {
            guard let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) else { return }
            selectedRecipe = RecipeSelection(id: recipe.id, feed: feed, recipe: recipe)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .foregroundStyle(.primary)
                Text(feed.siteURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .contextMenu {
            Button {
                exportPetal(feed: feed)
            } label: {
                Label(String(localized: "Manage.Export", table: "Petal"), systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Import

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = String(localized: "Error.ImportFailed", table: "Petal")
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let package = try PetalPackage.importPackage(from: url)
                _ = try feedManager.addPetalFeed(
                    recipe: package.recipe, iconData: package.iconData
                )
            } catch let error as LocalizedError {
                importError = error.errorDescription
                showImportError = true
            } catch {
                importError = String(localized: "Error.ImportFailed", table: "Petal")
                showImportError = true
            }
        case .failure:
            importError = String(localized: "Error.ImportFailed", table: "Petal")
            showImportError = true
        }
    }

    // MARK: - Export

    private func exportPetal(feed: Feed) {
        guard let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) else { return }
        let iconData = PetalRecipe.recipeID(from: feed.url)
            .flatMap { PetalStore.shared.iconData(for: $0) }
        do {
            let tempURL = try PetalPackage.exportToTempFile(
                recipe: recipe, iconPNG: iconData
            )
            shareItem = PetalShareItem(url: tempURL)
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }
}

// MARK: - UIActivityViewController wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context: Context) {}
}
