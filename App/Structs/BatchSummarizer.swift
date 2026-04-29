import Foundation
import FoundationModels

/// Runs LLM batch summarization concurrently then combines into a single summary.
enum BatchSummarizer {

    static let minArticleBodyCharacters = 200

    /// Returns true when `summary` has enough real content beyond the title to feed the LLM.
    static func hasUsefulContent(title: String, summary: String?) -> Bool {
        guard let summary, !summary.isEmpty else { return false }

        let stripped = summary
            .replacingOccurrences(
                of: "<[^>]+>",
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard stripped.count >= minArticleBodyCharacters else { return false }

        if stripped.caseInsensitiveCompare(title) == .orderedSame {
            return false
        }
        return true
    }

    /// Summarizes batches concurrently (max 3 at a time), then combines.
    static func summarize(
        batches: [String],
        instructions: String,
        combineInstructions: String
    ) async throws -> String {
        var batchSummaries: [String] = []

        try await withThrowingTaskGroup(of: String.self) { group in
            var index = 0

            while index < batches.count && index < 3 {
                let batch = batches[index]
                group.addTask {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: batch)
                    return response.content
                }
                index += 1
            }

            for try await result in group {
                batchSummaries.append(result)
                if index < batches.count {
                    let batch = batches[index]
                    group.addTask {
                        let session = LanguageModelSession(instructions: instructions)
                        let response = try await session.respond(to: batch)
                        return response.content
                    }
                    index += 1
                }
            }
        }

        guard !batchSummaries.isEmpty else { return "" }

        if batchSummaries.count == 1 {
            return batchSummaries[0]
        }

        let combined = batchSummaries.joined(separator: "\n\n")
        let session = LanguageModelSession(instructions: combineInstructions)
        let response = try await session.respond(to: combined)
        return response.content
    }

    /// Packs strings into batches fitting within `charLimit`.
    static func packBatches(_ descriptions: [String], charLimit: Int) -> [String] {
        var batches: [String] = []
        var current: [String] = []
        var currentLength = 0

        for desc in descriptions {
            let added = currentLength == 0 ? desc.count : desc.count + 2
            if !current.isEmpty && currentLength + added > charLimit {
                batches.append(current.joined(separator: "\n\n"))
                current = []
                currentLength = 0
            }
            current.append(desc)
            currentLength += added
        }
        if !current.isEmpty {
            batches.append(current.joined(separator: "\n\n"))
        }
        return batches
    }
}
