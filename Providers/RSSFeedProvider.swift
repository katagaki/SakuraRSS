import Foundation

/// A provider whose feeds are real RSS/Atom URLs and refresh through the
/// generic RSS pipeline. Conformance is a marker; metadata customisation is
/// delivered via `MetadataFetchingProvider`.
protocol RSSFeedProvider: FeedProvider {}
