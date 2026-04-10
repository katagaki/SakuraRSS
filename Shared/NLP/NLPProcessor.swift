import Foundation
import NaturalLanguage
import os

nonisolated enum NLPProcessor {

    #if DEBUG
    static let logger = Logger(subsystem: "com.tsubuzaki.SakuraRSS", category: "NLP")
    #endif

    // MARK: - Hybrid Scoring Tunables

    /// Weight applied to the normalized embedding similarity term in the
    /// hybrid ranker. The two weights should sum to 1.0.
    static let hybridEmbeddingWeight: Double = 0.65
    /// Weight applied to the entity Jaccard overlap term in the hybrid
    /// ranker. Ignored when the source article has no entities.
    static let hybridEntityWeight: Double = 0.35
    /// Cosine-distance ceiling returned by `NLEmbedding.distance`. Used to
    /// normalize distances to a [0, 1] similarity in the hybrid formula.
    static let maxEmbeddingDistance: Double = 2.0

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

    // MARK: - Similarity via NLEmbedding + Entity Overlap

    /// Ranks `candidates` by a hybrid score that blends normalized
    /// `NLEmbedding` sentence-embedding similarity with entity Jaccard
    /// overlap. See `hybridEmbeddingWeight` / `hybridEntityWeight`.
    ///
    /// - Parameters:
    ///   - article: Source article being viewed.
    ///   - sourceEntities: Lowercased entity names for the source article.
    ///     Pass an empty set to fall back to embedding-only scoring.
    ///   - candidates: Candidate articles paired with their lowercased
    ///     entity sets. Caller is expected to batch-load entities so this
    ///     function stays allocation-light.
    ///   - maxResults: Maximum number of ranked matches to return.
    ///   - minimumScore: Matches below this blended score are dropped.
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
            #if DEBUG
            logger.debug("findSimilarArticlesHybrid: no embedding available for language \(language.rawValue)")
            #endif
            return []
        }

        let hasSourceEntities = !sourceEntities.isEmpty
        let embeddingWeight = hasSourceEntities ? hybridEmbeddingWeight : 1.0
        let entityWeight = hasSourceEntities ? hybridEntityWeight : 0.0

        #if DEBUG
        logger.debug("findSimilarArticlesHybrid: comparing article \(article.id) against \(candidates.count) candidates (lang=\(language.rawValue), sourceEntities=\(sourceEntities.count))")
        #endif

        // NLEmbedding is not thread-safe — process serially.
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
        #if DEBUG
        logger.debug("findSimilarArticlesHybrid: returning \(results.count) matches (best score: \(String(format: "%.3f", results.first?.score ?? -1)))")
        #endif
        return results
    }

    /// Combined text fed into the sentence embedding. Title is repeated so
    /// it dominates summary content in the resulting vector — short, cheap,
    /// and noticeably helpful for headline-driven feeds.
    private static func articleText(_ article: Article) -> String {
        let title = article.title
        let summary = article.summary ?? ""
        if summary.isEmpty {
            return title
        }
        return title + " " + title + " " + summary
    }
}

