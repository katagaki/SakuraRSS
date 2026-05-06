import Foundation

/// Navigation value for the per-headline article list.
struct SummaryHeadlineDestination: Hashable {
    let title: String
    let articleIDs: [Int64]

    /// Stable zoom-transition ID matching `SummaryHeadlineCard.zoomTransitionID`.
    var zoomTransitionID: Int64 {
        articleIDs.first ?? 0
    }
}
