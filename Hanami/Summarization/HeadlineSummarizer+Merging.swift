import Foundation

extension HeadlineSummarizer {

    // MARK: - Same-Story Merging

    /// An event tagged with the model call that produced it, so merging
    /// can tell apart events the model deliberately kept separate within
    /// one call from duplicates produced by independent calls.
    struct BatchedEvent: Sendable {
        let callPath: String
        let event: ResolvedEvent
    }

    static let sharedEntityMergeThreshold = 2

    /// Merges events that describe the same story. Events sharing a
    /// source article always merge. Events from different model calls
    /// also merge when their articles share enough named entities,
    /// repairing stories that were split across batch boundaries and
    /// answered with one headline per batch. Events from the same call
    /// are never entity-merged, because the model saw both together and
    /// chose to keep them separate. The merged event keeps the headline
    /// of the constituent citing the most articles, unions all article
    /// IDs, and the result is ordered by source count so the
    /// best-corroborated stories survive the per-category cap.
    static func mergeSameStoryEvents(
        _ batched: [BatchedEvent],
        entityMap: [Int64: Set<String>]
    ) -> [ResolvedEvent] {
        guard batched.count > 1 else { return batched.map(\.event) }
        let groups = sameStoryGroups(batched, entityMap: entityMap)
        let mergedGroups: [(event: ResolvedEvent, firstIndex: Int)] = groups.map { indexes in
            let merged = mergedEvent(from: indexes.map { batched[$0].event })
            return (merged, indexes.min() ?? 0)
        }
        return mergedGroups
            .sorted { lhs, rhs in
                if lhs.event.articleIDs.count != rhs.event.articleIDs.count {
                    return lhs.event.articleIDs.count > rhs.event.articleIDs.count
                }
                return lhs.firstIndex < rhs.firstIndex
            }
            .map(\.event)
    }

    /// Union-find over event indexes: connected when two events share an
    /// article, or share entities across different model calls.
    private static func sameStoryGroups(
        _ batched: [BatchedEvent],
        entityMap: [Int64: Set<String>]
    ) -> [[Int]] {
        var parent = Array(0..<batched.count)

        func find(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }

        let articleSets = batched.map { Set($0.event.articleIDs) }
        let entitySets = batched.map { item in
            item.event.articleIDs.reduce(into: Set<String>()) { set, articleID in
                set.formUnion(entityMap[articleID] ?? [])
            }
        }
        for first in 0..<batched.count {
            for second in (first + 1)..<batched.count {
                let sharesArticle = !articleSets[first].isDisjoint(with: articleSets[second])
                let sharesEntities = batched[first].callPath != batched[second].callPath
                    && entitySets[first].intersection(entitySets[second]).count
                        >= sharedEntityMergeThreshold
                if sharesArticle || sharesEntities {
                    let rootA = find(first)
                    let rootB = find(second)
                    if rootA != rootB { parent[rootA] = rootB }
                }
            }
        }
        var memberIndexes: [Int: [Int]] = [:]
        for index in 0..<batched.count {
            memberIndexes[find(index), default: []].append(index)
        }
        return Array(memberIndexes.values)
    }

    private static func mergedEvent(from events: [ResolvedEvent]) -> ResolvedEvent {
        var base = events[0]
        for candidate in events.dropFirst() where candidate.articleIDs.count > base.articleIDs.count {
            base = candidate
        }
        var seen = Set<Int64>()
        var mergedIDs: [Int64] = []
        for event in events {
            for articleID in event.articleIDs where !seen.contains(articleID) {
                seen.insert(articleID)
                mergedIDs.append(articleID)
            }
        }
        return ResolvedEvent(
            headline: base.headline,
            articleIDs: mergedIDs,
            isMajorWorldEvent: events.contains(where: \.isMajorWorldEvent)
        )
    }
}
