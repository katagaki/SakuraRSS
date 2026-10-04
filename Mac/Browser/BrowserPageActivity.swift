import Observation

/// Work a tab's page is doing that the address bar should show, beyond feed
/// refreshes.
@Observable
final class BrowserPageActivity {
    var isExtractingContent = false
}
