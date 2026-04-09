import Foundation
import NaturalLanguage
import os

nonisolated enum NLPProcessor {

    #if DEBUG
    static let logger = Logger(subsystem: "com.tsubuzaki.SakuraRSS", category: "NLP")
    #endif

    struct EntityResult {
        let name: String
        let type: String
    }

    // MARK: - Entity Extraction

    static func extractEntities(from text: String) -> [EntityResult] {
        guard !text.isEmpty else { return [] }
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]

        var seen = Set<String>()
        var results: [EntityResult] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, range in
            guard let tag else { return true }
            let entityType: String?
            switch tag {
            case .personalName: entityType = "person"
            case .organizationName: entityType = "organization"
            case .placeName: entityType = "place"
            default: entityType = nil
            }
            if let entityType {
                let name = String(text[range]).trimmingCharacters(in: .whitespaces)
                let key = name.lowercased()
                if !key.isEmpty && key.count >= 2 && !seen.contains(key) {
                    seen.insert(key)
                    results.append(EntityResult(name: name, type: entityType))
                }
            }
            return true
        }
        #if DEBUG
        logger.debug("Extracted \(results.count) entities from text (\(text.count) chars)")
        #endif
        return results
    }

    // MARK: - Sentiment Analysis

    static func sentimentScore(for text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        var scores: [Double] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .paragraph,
            scheme: .sentimentScore,
            options: [.omitWhitespace]
        ) { tag, _ in
            if let tag, let score = Double(tag.rawValue) {
                scores.append(score)
            }
            return true
        }
        guard !scores.isEmpty else {
            #if DEBUG
            logger.debug("Sentiment: no scores extracted from \(text.count)-char text")
            #endif
            return nil
        }
        let average = scores.reduce(0, +) / Double(scores.count)
        #if DEBUG
        logger.debug("Sentiment: \(String(format: "%.3f", average)) (from \(scores.count) paragraphs)")
        #endif
        return average
    }

    // MARK: - Similarity via NLEmbedding

    static func findSimilarArticles(
        to article: Article,
        candidates: [Article],
        maxResults: Int = 10,
        maximumDistance: Double = 1.0
    ) async -> [(articleID: Int64, distance: Double)] {
        let sourceText = articleText(article)
        guard !sourceText.isEmpty else { return [] }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sourceText)
        let language = recognizer.dominantLanguage ?? .english
        let embedding = NLEmbedding.sentenceEmbedding(for: language)
            ?? NLEmbedding.sentenceEmbedding(for: .english)
        guard let embedding else {
            #if DEBUG
            logger.debug("findSimilarArticles: no embedding available for language \(language.rawValue)")
            #endif
            return []
        }

        #if DEBUG
        logger.debug("findSimilarArticles: comparing article \(article.id) against \(candidates.count) candidates (lang=\(language.rawValue))")
        #endif

        // Shard candidates across parallel tasks so distance computation
        // runs concurrently across multiple cores. NLEmbedding.distance is
        // thread-safe per Apple docs, but NLEmbedding itself isn't Sendable
        // — wrap it so it can cross task boundaries.
        let sendableEmbedding = UncheckedSendable(embedding)
        let shardCount = max(1, min(ProcessInfo.processInfo.activeProcessorCount, 8))
        let shardSize = max(1, (candidates.count + shardCount - 1) / shardCount)
        let shards = stride(from: 0, to: candidates.count, by: shardSize).map { start -> [Article] in
            Array(candidates[start..<min(start + shardSize, candidates.count)])
        }

        let scored: [(articleID: Int64, distance: Double)] = await withTaskGroup(
            of: [(articleID: Int64, distance: Double)].self
        ) { group in
            for shard in shards {
                group.addTask {
                    let embedding = sendableEmbedding.value
                    var local: [(articleID: Int64, distance: Double)] = []
                    local.reserveCapacity(shard.count)
                    for candidate in shard {
                        let candidateText = articleText(candidate)
                        guard !candidateText.isEmpty else { continue }
                        let distance = embedding.distance(between: sourceText, and: candidateText)
                        if distance <= maximumDistance {
                            local.append((articleID: candidate.id, distance: distance))
                        }
                    }
                    return local
                }
            }
            var combined: [(articleID: Int64, distance: Double)] = []
            for await result in group {
                combined.append(contentsOf: result)
            }
            return combined
        }

        let sorted = scored.sorted { $0.distance < $1.distance }
        let results = Array(sorted.prefix(maxResults))
        #if DEBUG
        logger.debug("findSimilarArticles: returning \(results.count) matches (best distance: \(String(format: "%.3f", results.first?.distance ?? -1)))")
        #endif
        return results
    }

    private static func articleText(_ article: Article) -> String {
        let title = article.title
        let summary = article.summary ?? ""
        if summary.isEmpty {
            return title
        }
        return title + " " + summary
    }
}

/// Bridges a non-Sendable Apple framework type across task boundaries.
/// Safe for types that are documented as thread-safe but not annotated Sendable.
nonisolated private struct UncheckedSendable<Value>: @unchecked Sendable {
    nonisolated(unsafe) let value: Value
    init(_ value: Value) { self.value = value }
}
