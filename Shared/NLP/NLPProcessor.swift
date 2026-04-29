import Foundation
import NaturalLanguage

nonisolated enum NLPProcessor {

    // MARK: - Hybrid Scoring Tunables

    // Weights should sum to 1.0.
    static let hybridEmbeddingWeight: Double = 0.65
    static let hybridEntityWeight: Double = 0.35
    static let maxEmbeddingDistance: Double = 2.0

    struct EntityResult {
        let name: String
        let type: String
    }

    // MARK: - Entity Extraction

    static func extractEntities(from text: String) -> [EntityResult] {
        guard !text.isEmpty else { return [] }
        let tagger = NLTagger(tagSchemes: [.nameType])
        return extractEntities(from: text, using: tagger)
    }

    /// Batch-friendly variant reusing a caller-owned `.nameType` tagger.
    static func extractEntities(from text: String, using tagger: NLTagger) -> [EntityResult] {
        guard !text.isEmpty else { return [] }
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
        log("NLP", "Extracted \(results.count) entities from text (\(text.count) chars)")
        return results
    }

    // MARK: - Sentiment Analysis

    static func sentimentScore(for text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        return sentimentScore(for: text, using: tagger)
    }

    /// Batch-friendly variant reusing a caller-owned `.sentimentScore` tagger.
    static func sentimentScore(for text: String, using tagger: NLTagger) -> Double? {
        guard !text.isEmpty else { return nil }
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
            log("NLP", "Sentiment: no scores extracted from \(text.count)-char text")
            return nil
        }
        let average = scores.reduce(0, +) / Double(scores.count)
        log("NLP", "Sentiment: \(String(format: "%.3f", average)) (from \(scores.count) paragraphs)")
        return average
    }

    // MARK: - Similarity via NLEmbedding + Entity Overlap

    /// Ranks candidates by blended embedding similarity and entity Jaccard overlap.
    static func findSimilarArticlesHybrid(
        to article: Article,
        sourceEntities: Set<String>,
        candidates: [(article: Article, entities: Set<String>)],
        maxResults: Int = 10,
        minimumScore: Double = 0.35
    ) async -> [(articleID: Int64, score: Double)] {
        let sourceText = articleText(article)
        guard !sourceText.isEmpty else { return [] }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sourceText)
        let language = recognizer.dominantLanguage ?? .english
        let embedding = NLEmbedding.sentenceEmbedding(for: language)
            ?? NLEmbedding.sentenceEmbedding(for: .english)
        guard let embedding else {
            log("NLP", "findSimilarArticlesHybrid: no embedding available for language \(language.rawValue)")
            return []
        }

        let hasSourceEntities = !sourceEntities.isEmpty
        let embeddingWeight = hasSourceEntities ? hybridEmbeddingWeight : 1.0
        let entityWeight = hasSourceEntities ? hybridEntityWeight : 0.0

        // swiftlint:disable:next line_length
        log("NLP", "findSimilarArticlesHybrid: comparing article \(article.id) against \(candidates.count) candidates (lang=\(language.rawValue), sourceEntities=\(sourceEntities.count))")

        // NLEmbedding is not thread-safe - process serially.
        var scored: [(articleID: Int64, score: Double)] = []
        scored.reserveCapacity(candidates.count)
        for candidate in candidates {
            let candidateText = articleText(candidate.article)
            guard !candidateText.isEmpty else { continue }

            let distance = embedding.distance(between: sourceText, and: candidateText)
            let normalized = min(max(distance / maxEmbeddingDistance, 0.0), 1.0)
            let embeddingSim = 1.0 - normalized

            let entityJaccard: Double
            if hasSourceEntities && !candidate.entities.isEmpty {
                let intersectionCount = sourceEntities.intersection(candidate.entities).count
                let unionCount = sourceEntities.union(candidate.entities).count
                entityJaccard = unionCount == 0 ? 0.0 : Double(intersectionCount) / Double(unionCount)
            } else {
                entityJaccard = 0.0
            }

            let score = embeddingWeight * embeddingSim + entityWeight * entityJaccard
            if score >= minimumScore {
                scored.append((articleID: candidate.article.id, score: score))
            }
        }

        let sorted = scored.sorted { $0.score > $1.score }
        let results = Array(sorted.prefix(maxResults))
        // swiftlint:disable:next line_length
        log("NLP", "findSimilarArticlesHybrid: returning \(results.count) matches (best score: \(String(format: "%.3f", results.first?.score ?? -1)))")
        return results
    }

    // Title is repeated so it dominates summary content in the embedding vector.
    private static func articleText(_ article: Article) -> String {
        let title = article.title
        let summary = article.summary ?? ""
        if summary.isEmpty {
            return title
        }
        return title + " " + title + " " + summary
    }
}
