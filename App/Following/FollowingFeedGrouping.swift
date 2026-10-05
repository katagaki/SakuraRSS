import Foundation
import Hanami

extension Array where Element == Feed {

    /// Groups feeds by section once, so each section doesn't re-filter and
    /// re-sort the whole feed list on every body evaluation.
    func groupedByFeedSection() -> [FeedSection: [Feed]] {
        var grouped = Dictionary(grouping: self, by: \.feedSection)
        for (section, feeds) in grouped where section != .feeds {
            grouped[section] = feeds.sorted {
                let domainCompare = $0.domain.localizedStandardCompare($1.domain)
                if domainCompare != .orderedSame { return domainCompare == .orderedAscending }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
        return grouped
    }
}
