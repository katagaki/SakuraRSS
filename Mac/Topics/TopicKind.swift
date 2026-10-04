import Foundation

/// The two kinds of subject Content Insights finds, by the entity types each
/// covers, as iOS's Topics page groups them.
nonisolated enum TopicKind {
    case topic
    case person

    var entityTypes: [String] {
        switch self {
        case .topic: ["organization", "place"]
        case .person: ["person"]
        }
    }
}
