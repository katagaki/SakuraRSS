import Foundation

nonisolated extension PetalEngine {

    // MARK: - Fetching

    /// Dispatches to the static or rendered fetch path for the recipe.
    static func fetchHTML(
        for recipe: PetalRecipe,
        pageURL overrideURL: String?
    ) async -> String? {
        let urlString = overrideURL?.isEmpty == false
            ? overrideURL! : recipe.siteURL
        guard let url = URL(string: urlString) else { return nil }

        switch recipe.fetchMode {
        case .staticHTML:
            return await fetchStaticHTML(from: url)
        case .rendered:
            return await fetchRenderedHTML(from: url)
        }
    }

    // MARK: - Static HTML

    private static func fetchStaticHTML(from url: URL) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(
                for: .sakura(url: url, timeoutInterval: 15)
            )
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return nil
            }
            return String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        } catch {
            return nil
        }
    }

    // MARK: - Rendered HTML (WKWebView)

    /// Loads the page in a `WKWebView` and waits for JS hydration.
    private static func fetchRenderedHTML(from url: URL) async -> String? {
        await Task { @MainActor in
            await PetalWebViewLoader().loadHTML(from: url)
        }.value
    }
}
