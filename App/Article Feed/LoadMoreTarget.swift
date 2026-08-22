import Foundation

/// The next batching window to load, resolved when the batcher inputs change
/// rather than during body evaluation.
enum LoadMoreTarget: Equatable {
    case sinceDate(Date)
    case count(Int)
}
