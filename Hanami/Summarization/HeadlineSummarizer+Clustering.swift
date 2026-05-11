import Foundation

extension HeadlineSummarizer {

    // MARK: - Clustering & Batching

    /// Groups inputs that share at least 2 named entities (people, places,
    /// organizations) so articles about the same story end up in the same
    /// batch. Articles without entities, or whose entities don't overlap
    /// with anyone else's, become singleton clusters. Order within a cluster
    /// preserves the original order. Clusters containing at least one
    /// preferred-feed article are returned first; remaining ties break on
    /// cluster size and original article order.
    static func clusterByEntities(
        inputs: [Input],
        entityMap: [Int64: Set<String>],
        preferredFeedIDs: Set<Int64> = [],
        sharedThreshold: Int = 2
    ) -> [[Input]] {
        guard !inputs.isEmpty else { return [] }
        var parent = Array(0..<inputs.count)

        func find(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }

        func union(_ first: Int, _ second: Int) {
            let rootA = find(first)
            let rootB = find(second)
            if rootA != rootB { parent[rootA] = rootB }
        }

        for indexA in 0..<inputs.count {
            let entitiesA = entityMap[inputs[indexA].articleID] ?? []
            guard !entitiesA.isEmpty else { continue }
            for indexB in (indexA + 1)..<inputs.count {
                let entitiesB = entityMap[inputs[indexB].articleID] ?? []
                guard !entitiesB.isEmpty else { continue }
                if entitiesA.intersection(entitiesB).count >= sharedThreshold {
                    union(indexA, indexB)
                }
            }
        }

        var groups: [Int: [Input]] = [:]
        var firstSeen: [Int: Int] = [:]
        for index in 0..<inputs.count {
            let root = find(index)
            groups[root, default: []].append(inputs[index])
            if firstSeen[root] == nil { firstSeen[root] = index }
        }
        return groups
            .sorted { lhs, rhs in
                let lhsPreferred = lhs.value.contains { preferredFeedIDs.contains($0.feedID) }
                let rhsPreferred = rhs.value.contains { preferredFeedIDs.contains($0.feedID) }
                if lhsPreferred != rhsPreferred {
                    return lhsPreferred && !rhsPreferred
                }
                if lhs.value.count != rhs.value.count {
                    return lhs.value.count > rhs.value.count
                }
                return (firstSeen[lhs.key] ?? 0) < (firstSeen[rhs.key] ?? 0)
            }
            .map(\.value)
    }

    /// Packs whole clusters into batches without splitting a cluster across
    /// batch boundaries when possible. A cluster larger than `charLimit`
    /// falls back to character-greedy packing within its own batch space.
    static func packClusters(_ clusters: [[Input]], charLimit: Int) -> [[Input]] {
        var batches: [[Input]] = []
        var current: [Input] = []
        var currentLength = 0

        func flush() {
            if !current.isEmpty {
                batches.append(current)
                current = []
                currentLength = 0
            }
        }

        for cluster in clusters {
            let clusterLength = cluster.reduce(0) { sum, input in
                sum + input.description.count + 8
            }
            if clusterLength > charLimit {
                flush()
                let parts = packBatches(cluster, charLimit: charLimit)
                batches.append(contentsOf: parts)
                continue
            }
            if !current.isEmpty && currentLength + clusterLength > charLimit {
                flush()
            }
            current.append(contentsOf: cluster)
            currentLength += clusterLength
        }
        flush()
        return batches
    }

    static func packBatches(_ articles: [Input], charLimit: Int) -> [[Input]] {
        var batches: [[Input]] = []
        var current: [Input] = []
        var currentLength = 0
        for article in articles {
            let lineLength = article.description.count + 6
            let added = currentLength == 0 ? lineLength : lineLength + 2
            if !current.isEmpty && currentLength + added > charLimit {
                batches.append(current)
                current = []
                currentLength = 0
            }
            current.append(article)
            currentLength += added
        }
        if !current.isEmpty {
            batches.append(current)
        }
        return batches
    }

    static func renderPrompt(_ batch: [Input]) -> String {
        batch.map(\.description).joined(separator: "\n---\n")
    }

    /// Matches FoundationModels' safety rejection by localizedDescription so
    /// we don't depend on a private case identifier.
    static func isGuardrailViolation(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("unsafe")
            || description.contains("guardrail")
            || description.contains("safety")
    }
}
