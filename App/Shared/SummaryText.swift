import SwiftUI
import Hanami

struct SummaryText: View {

    // NSCache is thread-safe.
    nonisolated(unsafe) private static let strippedCache = NSCache<NSString, NSString>()

    let summary: String
    @State private var stripped: String
    @State private var strippedSource: String?

    init(summary: String) {
        self.summary = summary
        let initial = Self.strippedCache.object(forKey: summary as NSString) as String?
        _stripped = State(initialValue: initial ?? "")
        _strippedSource = State(initialValue: initial == nil ? nil : summary)
    }

    var body: some View {
        Text(strippedSource == summary ? stripped : "")
            .task(id: summary, priority: .utility) {
                if strippedSource == summary { return }
                let result = await Self.strip(summary)
                if Task.isCancelled { return }
                stripped = result
                strippedSource = summary
            }
    }

    @concurrent nonisolated private static func strip(_ summary: String) async -> String {
        if let existing = strippedCache.object(forKey: summary as NSString) {
            return existing as String
        }
        let result = ContentBlock.stripMarkdown(summary)
        strippedCache.setObject(result as NSString, forKey: summary as NSString)
        return result
    }
}
