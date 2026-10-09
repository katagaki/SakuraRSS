import Foundation
import Hanami

/// Navigation value for the per-headline article list.
struct SummaryHeadlineDestination: Hashable {
    let title: String
    let articleIDs: [Int64]
}
