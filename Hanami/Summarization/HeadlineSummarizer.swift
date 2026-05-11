import Foundation
import FoundationModels
import NaturalLanguage

@Generable
struct HeadlineEvent: Sendable {
    @Guide(description: "A short, specific headline of 12 words or fewer summarizing this important event.")
    var headline: String
    @Guide(
        // swiftlint:disable:next line_length
        description: "The exact ID numbers of the source articles describing this event. Copy each ID verbatim from the `ID:` line of the matching articles. Only include IDs that appear in the input. Do not invent IDs."
    )
    var articleIDs: [Int]
}

@Generable
struct HeadlineEventList: Sendable {
    @Guide(description: "Up to 5 distinct important events grouped from the input articles.")
    var events: [HeadlineEvent]
}

/// Runs structured-output headline grouping in batches that fit the on-device
/// context window. Articles are tagged with their real `Article.id` in the
/// prompt; the model echoes those IDs back, and we filter to IDs that appear
/// in each batch before flat-merging across batches.
public enum HeadlineSummarizer {

    nonisolated static let logModule = "Summary"
    static let batchCharLimit = 3000
    public static let snippetCharLimit = 300
    public static let maxArticlesConsidered = 30
    static let maxConcurrentBatches = 3

    /// Cap on returned events that scales with input size so light days
    /// don't get padded out to five headlines.
    public static func maxEvents(for inputCount: Int) -> Int {
        switch inputCount {
        case ..<5: return 1
        case 5..<10: return 2
        case 10..<18: return 3
        case 18..<25: return 4
        default: return 5
        }
    }

    public struct Input: Sendable {
        public let articleID: Int64
        public let feedID: Int64
        public let description: String

        public init(articleID: Int64, feedID: Int64 = 0, description: String) {
            self.articleID = articleID
            self.feedID = feedID
            self.description = description
        }
    }

    public struct ResolvedEvent: Sendable {
        public let headline: String
        public let articleIDs: [Int64]
    }

    /// Returns surviving events alongside the last non-guardrail error, if
    /// any. Callers persist partial results when events is non-empty even
    /// if error is set, so a cancelled batch doesn't wipe the section.
    public static func summarize(
        articles: [Input],
        instructions: String,
        entityMap: [Int64: Set<String>] = [:],
        preferredFeedIDs: Set<Int64> = []
    ) async -> (events: [ResolvedEvent], error: Error?) {
        let filtered = articles.filter { input in
            !RejectPatterns.matchesAny(input.description)
        }
        let clusters = clusterByEntities(
            inputs: filtered,
            entityMap: entityMap,
            preferredFeedIDs: preferredFeedIDs
        )
        let clusterSizes = clusters.map(\.count)
        log(
            logModule,
            "clustering: clusters=\(clusters.count) sizes=\(clusterSizes) (entityMap=\(entityMap.count) articles)"
        )
        let batches = packClusters(clusters, charLimit: batchCharLimit)
        log(logModule, "summarize: input=\(articles.count) filtered=\(filtered.count) batches=\(batches.count)")
        log(logModule, "instructions length=\(instructions.count) chars")
        guard !batches.isEmpty else {
            log(logModule, "no batches after filtering; returning empty")
            return ([], nil)
        }

        let (events, lastNonGuardrailError) = await runBatches(
            batches: batches,
            instructions: instructions
        )

        if events.isEmpty {
            if let lastNonGuardrailError {
                log(
                    logModule,
                    "all batches failed; surfacing error: \(lastNonGuardrailError.localizedDescription)"
                )
            } else {
                log(logModule, "no events extracted from any batch")
            }
            return ([], lastNonGuardrailError)
        }
        let cap = maxEvents(for: articles.count)
        let deduped = Array(deduplicate(events).prefix(cap))
        log(logModule, "raw events=\(events.count) after dedup+cap(\(cap))=\(deduped.count)")
        let translated = await translateHeadlinesIfNeeded(deduped)
        return (translated, lastNonGuardrailError)
    }

    /// Detects each headline's language and runs a translation pass on
    /// anything that isn't in the user's locale. The model frequently
    /// ignores in-prompt language directives when the source articles are
    /// in a different language, so this is a deterministic safety net.
    private static func translateHeadlinesIfNeeded(
        _ events: [ResolvedEvent]
    ) async -> [ResolvedEvent] {
        let target = userLanguageCode
        return await withTaskGroup(of: (Int, ResolvedEvent).self) { group in
            for (index, event) in events.enumerated() {
                group.addTask {
                    let detected = detectLanguage(of: event.headline)
                    if detected == nil || detected == target {
                        return (index, event)
                    }
                    log(
                        logModule,
                        "translating headline (detected=\(detected ?? "?") -> \(target)): \(event.headline)"
                    )
                    if let translated = await translate(headline: event.headline),
                       !translated.isEmpty {
                        return (
                            index,
                            ResolvedEvent(headline: translated, articleIDs: event.articleIDs)
                        )
                    }
                    return (index, event)
                }
            }
            var indexed: [(Int, ResolvedEvent)] = []
            for await item in group { indexed.append(item) }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    nonisolated private static func detectLanguage(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    private static func translate(headline: String) async -> String? {
        let langName = Locale(identifier: "en")
            .localizedString(forLanguageCode: userLanguageCode) ?? "English"
        let instructions = "Translate the user's text into \(langName). "
            + "Output only the translated text. Keep proper nouns. Do not add commentary."
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: headline)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            log(logModule, "translation failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static var userLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    /// Drops batches that trip the safety classifier; surfaces other errors
    /// only if no batch survived.
    private static func runBatches(
        batches: [[Input]],
        instructions: String
    ) async -> (events: [ResolvedEvent], lastNonGuardrailError: Error?) {
        var resolved: [ResolvedEvent] = []
        var lastError: Error?
        await withTaskGroup(of: Result<[ResolvedEvent], Error>.self) { group in
            var index = 0
            while index < batches.count && index < maxConcurrentBatches {
                let batch = batches[index]
                let batchIndex = index
                group.addTask {
                    await runBatch(batchIndex: batchIndex, batch: batch, instructions: instructions)
                }
                index += 1
            }
            for await outcome in group {
                switch outcome {
                case .success(let events):
                    resolved.append(contentsOf: events)
                case .failure(let error):
                    if !isGuardrailViolation(error) {
                        lastError = error
                    }
                }
                if index < batches.count {
                    let batch = batches[index]
                    let batchIndex = index
                    group.addTask {
                        await runBatch(batchIndex: batchIndex, batch: batch, instructions: instructions)
                    }
                    index += 1
                }
            }
        }
        return (resolved, lastError)
    }

    private static func runBatch(
        batchIndex: Int,
        batch: [Input],
        instructions: String
    ) async -> Result<[ResolvedEvent], Error> {
        let prompt = renderPrompt(batch)
        log(
            logModule,
            "batch[\(batchIndex)]: articles=\(batch.count) promptChars=\(prompt.count)"
        )
        log(logModule, "batch[\(batchIndex)] prompt:\n\(prompt)")
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: prompt,
                generating: HeadlineEventList.self
            )
            let events = response.content.events
            log(
                logModule,
                "batch[\(batchIndex)] received \(events.count) raw events"
            )
            for (eventIndex, event) in events.enumerated() {
                log(
                    logModule,
                    "batch[\(batchIndex)] event[\(eventIndex)]: ids=\(event.articleIDs) headline=\(event.headline)"
                )
            }
            let resolved = resolve(events: events, batch: batch)
            log(
                logModule,
                "batch[\(batchIndex)] resolved \(resolved.count) of \(events.count) events"
            )
            return .success(resolved)
        } catch {
            if isGuardrailViolation(error) {
                log(logModule, "batch[\(batchIndex)] dropped (guardrail): \(error.localizedDescription)")
            } else {
                log(logModule, "batch[\(batchIndex)] failed: \(error.localizedDescription)")
            }
            return .failure(error)
        }
    }

    /// Filters each event's articleIDs to those present in the batch and
    /// drops events that end up empty (the model emitted bogus IDs).
    private static func resolve(
        events: [HeadlineEvent],
        batch: [Input]
    ) -> [ResolvedEvent] {
        let validIDs: Set<Int64> = Set(batch.map(\.articleID))
        return events.compactMap { event in
            let cleanedHeadline = event.headline.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedHeadline.isEmpty else { return nil }
            var seen: Set<Int64> = []
            var ids: [Int64] = []
            for value in event.articleIDs {
                let candidate = Int64(value)
                guard validIDs.contains(candidate), !seen.contains(candidate) else { continue }
                seen.insert(candidate)
                ids.append(candidate)
            }
            guard !ids.isEmpty else { return nil }
            return ResolvedEvent(headline: cleanedHeadline, articleIDs: ids)
        }
    }

    private static func deduplicate(_ events: [ResolvedEvent]) -> [ResolvedEvent] {
        var seen = Set<String>()
        var output: [ResolvedEvent] = []
        for event in events {
            let signature = event.articleIDs.sorted().map(String.init).joined(separator: ",")
            guard !seen.contains(signature) else { continue }
            seen.insert(signature)
            output.append(event)
        }
        return output
    }

}
