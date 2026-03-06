import Foundation
import FoundationModels

/// Runs LLM batch summarization: splits content into batches, summarizes each concurrently,
/// then combines into a single summary.
enum BatchSummarizer {

    /// Summarizes batches concurrently (max 3 at a time), then combines results if needed.
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

    /// Packs strings into batches that each fit within the given character limit.
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
