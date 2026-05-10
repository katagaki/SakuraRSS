import SwiftUI
import Hanami

extension HomeSectionView {

    var isVideoSection: Bool {
        section == .youtube || section == .vimeo || section == .niconico
    }

    var isFeedViewSection: Bool {
        section == .x || section == .fediverse || section == .bluesky
    }

    var isPodcastSection: Bool {
        section == .podcasts
    }

    var title: String {
        switch source {
        case .section(let section):
            return section?.localizedTitle ?? HomeSection.all.localizedTitle
        case .list(let list):
            return list.name
        case .topic(let name):
            return name
        }
    }

    var feedKey: String {
        switch source {
        case .section(let section):
            if let section { return "home.\(section.rawValue)" }
            return "all"
        case .list(let list):
            return "list.\(list.id)"
        case .topic(let name):
            return "topic.\(name)"
        }
    }

    var scopeKey: String {
        switch source {
        case .section(let section):
            if let section { return "section.\(section.rawValue)" }
            return "section.all"
        case .list(let list):
            return "list.\(list.id)"
        case .topic(let name):
            return "topic.\(name)"
        }
    }

    var scopedFeeds: [Feed] {
        switch source {
        case .section(let section):
            guard let section else { return feedManager.feeds }
            return feedManager.feeds.filter { $0.feedSection == section }
        case .list(let list):
            return feedManager.feeds(for: list)
        case .topic:
            return feedManager.feeds
        }
    }

    var scopedRefreshState: ScopedRefreshState {
        feedManager.scopedRefreshes[scopeKey] ?? ScopedRefreshState()
    }

    func performMarkAllRead() {
        switch source {
        case .section(let section):
            if let section {
                feedManager.markAllRead(for: section)
            } else {
                feedManager.markAllRead()
            }
        case .list(let list):
            feedManager.markAllRead(for: list)
        case .topic:
            for article in rawArticles where !feedManager.isRead(article) {
                feedManager.markRead(article)
            }
        }
    }

    var headerView: AnyView? {
        guard showsListHeader, case .list(let list) = source else { return nil }
        return AnyView(ListHeaderView(list: list).environment(feedManager))
    }
}
