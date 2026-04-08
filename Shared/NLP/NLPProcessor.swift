import Foundation
import NaturalLanguage

nonisolated enum NLPProcessor {

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
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Similarity via NLEmbedding

    static func findSimilarArticles(
        to article: Article,
        candidates: [Article],
        maxResults: Int = 10,
        maximumDistance: Double = 1.0
    ) -> [(articleID: Int64, distance: Double)] {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            return []
        }

        let sourceText = articleText(article)
        guard !sourceText.isEmpty else { return [] }

        var scored: [(articleID: Int64, distance: Double)] = []

        for candidate in candidates {
            let candidateText = articleText(candidate)
            guard !candidateText.isEmpty else { continue }
            let distance = embedding.distance(between: sourceText, and: candidateText)
            if distance <= maximumDistance {
                scored.append((articleID: candidate.id, distance: distance))
            }
        }

        scored.sort { $0.distance < $1.distance }
        return Array(scored.prefix(maxResults))
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
