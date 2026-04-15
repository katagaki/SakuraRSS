import Foundation

nonisolated extension PetalEngine {

    // MARK: - Fetching

    /// Dispatches to the right fetch path for the recipe's mode.
    /// Package-internal (not `private`) because the main file's
    /// public entry points call into it from across the file
    /// boundary.
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

    /// Straight-through `URLSession` GET.  Uses the shared
    /// `URLRequest.sakura(...)` helper so Web Feed requests look
    /// identical to the rest of the app's RSS traffic.
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

    /// Loads the page in a `WKWebView` and waits for JS
    /// hydration — needed for React / Vue / Next single-page
    /// apps whose initial HTML response is a near-empty shell.
    ///
    /// The loader is `@MainActor` because `WKWebView` has to
    /// live on the main thread, so construction *and* the
    /// suspending `loadHTML` call are both wrapped in a single
    /// main-actor `Task` to keep the reference from ever
    /// escaping the main actor.
    private static func fetchRenderedHTML(from url: URL) async -> String? {
        await Task { @MainActor in
            await PetalWebViewLoader().loadHTML(from: url)
        }.value
    }
}
