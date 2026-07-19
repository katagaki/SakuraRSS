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
    @Guide(
        // swiftlint:disable:next line_length
        description: "true when this is major world or national news every reader should know about (politics, international affairs, conflicts, disasters, public safety, or economy-wide developments). false when the event mainly matters to readers who follow the topic."
    )
    var isMajorWorldEvent: Bool
}

@Generable
struct HeadlineEventList: Sendable {
    @Guide(description: "Up to 5 distinct important events grouped from the input articles.")
    var events: [HeadlineEvent]
}

/// Runs structured-output headline grouping in batches that fit the on-device
/// context window. Articles are tagged with their real `Article.id` in the
/// prompt; the model echoes those IDs back, and we filter to IDs that appear
/// in each batch before merging same-story events across batches.
public enum HeadlineSummarizer {

    nonisolated static let logModule = "Summary"
    static let batchCharLimit = 3000
    public static let snippetCharLimit = 300
    public static let maxArticlesConsidered = 30
    static let maxConcurrentBatches = 3

    /// Bump whenever the headline prompt template, input format, event
    /// cap, or resolver changes in a way that would invalidate cached
    /// rows. The DB wipes the summary_headlines cache on next launch
    /// when this differs from the stored value, independent of app
    /// version.
    public nonisolated static let promptVersion = 3

    /// Per-category cap on returned events that scales with input size so
    /// light days don't get padded out. Applied separately to
    /// reader-interest events and major world events, so the overall
    /// maximum is twice this value (10 on busy days).
    public static func maxEventsPerCategory(for inputCount: Int) -> Int {
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
        public let isMajorWorldEvent: Bool
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

        let (batchedEvents, lastNonGuardrailError) = await runBatches(
            batches: batches,
            instructions: instructions
        )

        if batchedEvents.isEmpty {
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
        let cap = maxEventsPerCategory(for: articles.count)
        let merged = mergeSameStoryEvents(batchedEvents, entityMap: entityMap)
        let interestEvents = Array(merged.filter { !$0.isMajorWorldEvent }.prefix(cap))
        let keyEvents = Array(merged.filter(\.isMajorWorldEvent).prefix(cap))
        // swiftlint:disable:next line_length
        log(logModule, "raw events=\(batchedEvents.count) merged=\(merged.count) interest=\(interestEvents.count) keyEvents=\(keyEvents.count) (cap \(cap) each)")
        let translated = await translateHeadlinesIfNeeded(interestEvents + keyEvents)
        return (translated, lastNonGuardrailError)
    }

    /// Drops batches that trip the safety classifier; surfaces other errors
    /// only if no batch survived. Stops scheduling new batches once the
    /// surrounding task is cancelled (e.g. a background task expiring) so
    /// whatever already resolved can still be persisted as a partial result.
    private static func runBatches(
        batches: [[Input]],
        instructions: String
    ) async -> (events: [BatchedEvent], lastNonGuardrailError: Error?) {
        var resolved: [BatchedEvent] = []
        var lastError: Error?
        await withTaskGroup(of: Result<[BatchedEvent], Error>.self) { group in
            var index = 0
            while index < batches.count && index < maxConcurrentBatches && !Task.isCancelled {
                scheduleBatch(&group, batches: batches, index: index, instructions: instructions)
                index += 1
            }
            for await outcome in group {
                switch outcome {
                case .success(let events):
                    resolved.append(contentsOf: events)
                case .failure(let error) where !isGuardrailViolation(error):
                    lastError = error
                case .failure:
                    break
                }
                if index < batches.count && !Task.isCancelled {
                    scheduleBatch(&group, batches: batches, index: index, instructions: instructions)
                    index += 1
                }
            }
            if Task.isCancelled && index < batches.count {
                log(logModule, "cancelled; skipped \(batches.count - index) remaining batches")
                lastError = lastError ?? CancellationError()
            }
        }
        return (resolved, lastError)
    }

    private static func scheduleBatch(
        _ group: inout TaskGroup<Result<[BatchedEvent], Error>>,
        batches: [[Input]],
        index: Int,
        instructions: String
    ) {
        let batch = batches[index]
        group.addTask {
            await runBatch(batchIndex: index, batch: batch, instructions: instructions)
        }
    }

    private static func runBatch(
        batchIndex: Int,
        batch: [Input],
        instructions: String,
        splitDepth: Int = 0,
        callPath: String? = nil
    ) async -> Result<[BatchedEvent], Error> {
        let path = callPath ?? String(batchIndex)
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
            logRawEvents(batchIndex: batchIndex, events: events)
            let resolved = resolve(events: events, batch: batch)
            log(
                logModule,
                "batch[\(batchIndex)] resolved \(resolved.count) of \(events.count) events"
            )
            return .success(resolved.map { BatchedEvent(callPath: path, event: $0) })
        } catch {
            if isContextWindowOverflow(error), batch.count > 1, splitDepth < 2 {
                log(
                    logModule,
                    "batch[\(batchIndex)] exceeded context window; splitting \(batch.count) articles and retrying"
                )
                return await runSplitBatch(
                    batchIndex: batchIndex,
                    batch: batch,
                    instructions: instructions,
                    splitDepth: splitDepth,
                    callPath: path
                )
            }
            if isGuardrailViolation(error) {
                log(logModule, "batch[\(batchIndex)] dropped (guardrail): \(error.localizedDescription)")
            } else {
                log(logModule, "batch[\(batchIndex)] failed: \(error.localizedDescription)")
            }
            return .failure(error)
        }
    }

    private static func logRawEvents(batchIndex: Int, events: [HeadlineEvent]) {
        log(logModule, "batch[\(batchIndex)] received \(events.count) raw events")
        for (eventIndex, event) in events.enumerated() {
            log(
                logModule,
                "batch[\(batchIndex)] event[\(eventIndex)]: ids=\(event.articleIDs) headline=\(event.headline)"
            )
        }
    }

    /// Runs the two halves of an oversized batch sequentially, merging
    /// whatever succeeds. Only fails when both halves fail. Each half is
    /// a separate model call, so it gets its own call path and duplicate
    /// events across halves can be entity-merged later.
    private static func runSplitBatch(
        batchIndex: Int,
        batch: [Input],
        instructions: String,
        splitDepth: Int,
        callPath: String
    ) async -> Result<[BatchedEvent], Error> {
        let middle = batch.count / 2
        let halves = [Array(batch[..<middle]), Array(batch[middle...])]
        var events: [BatchedEvent] = []
        var lastFailure: Error?
        for (halfIndex, half) in halves.enumerated() where !half.isEmpty {
            let outcome = await runBatch(
                batchIndex: batchIndex,
                batch: half,
                instructions: instructions,
                splitDepth: splitDepth + 1,
                callPath: "\(callPath).\(halfIndex)"
            )
            switch outcome {
            case .success(let halfEvents):
                events.append(contentsOf: halfEvents)
            case .failure(let error):
                lastFailure = error
            }
        }
        if events.isEmpty, let lastFailure {
            return .failure(lastFailure)
        }
        return .success(events)
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
            return ResolvedEvent(
                headline: cleanedHeadline,
                articleIDs: ids,
                isMajorWorldEvent: event.isMajorWorldEvent
            )
        }
    }

}
