import Foundation

/// What the address bar draws behind its label while the page it is naming is
/// busy. The browser has no room for Home's refresh pill, so the omnibox's own
/// background carries the progress instead.
enum BrowserAddressProgress: Equatable {
    case determinate(Double)
    /// Work that cannot be counted, or cannot be counted yet: the bar runs a
    /// marquee rather than parking a bar at zero.
    case indeterminate
}
