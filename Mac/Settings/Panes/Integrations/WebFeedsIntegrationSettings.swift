import Hanami
import SwiftUI

/// Web Feeds' switch and the feeds themselves on one page: each can be edited
/// or exported, and new ones imported, without opening another sheet.
struct WebFeedsIntegrationSettings: View {

    @AppStorage("Labs.PetalRecipes") private var webFeedsEnabled = false
    @Environment(FeedManager.self) private var feedManager
    @State private var editedRecipe: EditedRecipe?
    @State private var isImporting = false
    @State private var exportedFileURL: URL?
    @State private var errorMessage: String?

    private struct EditedRecipe: Identifiable {
        let feed: Feed
        let recipe: PetalRecipe
        var id: UUID { recipe.id }
    }

    private var webFeeds: [Feed] {
        feedManager.feeds
            .filter { PetalRecipe.isPetalFeedURL($0.url) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(IntegrationText.string("Petal"), isOn: $webFeedsEnabled)
            SettingsNote(text: IntegrationText.string("Petal.Footer"))
            if webFeedsEnabled {
                Text(String(localized: "Manage.Section.Installed", table: "Petal"))
                    .font(.headline)
                    .padding(.top, 12)
                if webFeeds.isEmpty {
                    Text(String(localized: "Manage.Empty", table: "Petal"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(webFeeds) { feed in
                        WebFeedRow(feed: feed, onEdit: { edit(feed) }, onExport: { export(feed) })
                        Divider()
                    }
                }
                Button(String(localized: "Manage.Import", table: "Petal") + "…") { isImporting = true }
                    .padding(.top, 4)
                SettingsNote(text: String(localized: "Manage.ImportFooter", table: "Petal"))
            }
        }
        .animation(.smooth.speed(2.0), value: webFeedsEnabled)
        .sheet(item: $editedRecipe) { edited in
            PetalBuilderView(mode: .edit(feed: edited.feed, recipe: edited.recipe))
                .environment(feedManager)
                .frame(minWidth: 600, minHeight: 640)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [PetalPackage.contentType]) { result in
            importPackage(result)
        }
        .fileMover(
            isPresented: Binding(get: { exportedFileURL != nil }, set: { if !$0 { exportedFileURL = nil } }),
            file: exportedFileURL
        ) { _ in
            exportedFileURL = nil
        }
        .alert(
            String(localized: "Error.Title", table: "Petal"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("Shared.OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func edit(_ feed: Feed) {
        guard let recipe = PetalStore.shared.recipe(forFeedURL: feed.url)
                ?? PetalRecipe.recoveryRecipe(name: feed.title, feedURL: feed.url) else { return }
        editedRecipe = EditedRecipe(feed: feed, recipe: recipe)
    }

    private func export(_ feed: Feed) {
        guard let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) else { return }
        do {
            exportedFileURL = try PetalPackage.exportToTempFile(
                recipe: recipe, iconPNG: PetalStore.shared.iconData(for: recipe.id)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importPackage(_ result: Result<URL, Error>) {
        let importFailed = String(localized: "Error.ImportFailed", table: "Petal")
        guard case .success(let url) = result, url.startAccessingSecurityScopedResource() else {
            errorMessage = importFailed
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let package = try PetalPackage.importPackage(from: url)
            _ = try feedManager.addPetalFeed(recipe: package.recipe, iconData: package.iconData)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? importFailed
        }
    }
}
