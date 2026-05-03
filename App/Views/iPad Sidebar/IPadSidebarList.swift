import SwiftUI

struct IPadSidebarList: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false

    @Binding var selectedDestination: SidebarDestination?
    @Binding var searchText: String
    @Binding var feedForEditSheet: FeedIDIdentifier?
    @Binding var feedToDelete: Feed?
    @Binding var listToEdit: FeedList?
    @Binding var listForRules: FeedList?
    @Binding var listToDelete: FeedList?
    @Binding var showingMore: Bool
    @Binding var showingAddFeed: Bool
    @Binding var showingNewList: Bool

    let availableSections: [FeedSection]
    let sectionIcon: (FeedSection) -> String
    let onDestinationChanged: () -> Void

    var body: some View {
        List(selection: $selectedDestination) {
            primarySection
            sectionsList
            listsSection
            followingSection
            profileSection
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: Text(String(localized: "Prompt", table: "Search")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addMenu
            }
        }
        .onChange(of: selectedDestination) { oldValue, newValue in
            if newValue == .more {
                showingMore = true
                selectedDestination = oldValue
            } else {
                onDestinationChanged()
            }
        }
        .sheet(isPresented: $showingMore) {
            MoreView()
                .environment(\.isSakuraBackgroundDisabled, true)
        }
        .sheet(isPresented: $showingNewList) {
            ListEditSheet(list: nil)
                .interactiveDismissDisabled()
        }
        .sheet(item: $feedForEditSheet) { wrapper in
            EditFeedSheet(feedID: wrapper.id)
        }
    }

    @ViewBuilder
    private var primarySection: some View {
        Section {
            Label(String(localized: "HomeSection.Today", table: "Home"), systemImage: "newspaper")
                .tag(SidebarDestination.today)
            Label(String(localized: "Sidebar.Following", table: "Feeds"), systemImage: "dot.radiowaves.up.forward")
                .tag(SidebarDestination.allArticles)
            Label("Tabs.Bookmarks", systemImage: "bookmark")
                .tag(SidebarDestination.bookmarks)
            if contentInsightsEnabled {
                Label(String(localized: "Topics.Title", table: "Articles"), systemImage: "number")
                    .tag(SidebarDestination.topics)
                Label(String(localized: "People.Title", table: "Articles"), systemImage: "person.2")
                    .tag(SidebarDestination.people)
            }
        }
    }

    @ViewBuilder
    private var sectionsList: some View {
        if !availableSections.isEmpty {
            Section {
                ForEach(availableSections, id: \.self) { section in
                    HStack {
                        Label(section.localizedTitle, systemImage: sectionIcon(section))
                        Spacer()
                        SidebarUnreadBadge(count: feedManager.unreadCount(for: section))
                    }
                    .tag(SidebarDestination.section(section))
                }
            }
        }
    }

    @ViewBuilder
    private var listsSection: some View {
        if !feedManager.lists.isEmpty {
            Section("Tabs.Lists") {
                ForEach(sortedLists) { list in
                    HStack {
                        Label(list.name, systemImage: list.icon)
                        Spacer()
                        SidebarUnreadBadge(count: feedManager.unreadCount(for: list))
                    }
                    .tag(SidebarDestination.list(list))
                    .contextMenu {
                        IPadSidebarListContextMenu(
                            list: list,
                            listToEdit: $listToEdit,
                            listForRules: $listForRules,
                            listToDelete: $listToDelete
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var followingSection: some View {
        ForEach(FeedSection.allCases, id: \.self) { section in
            let feeds = feedsForSection(section)
            if !feeds.isEmpty {
                Section {
                    ForEach(feeds) { feed in
                        NavigationLink(value: SidebarDestination.feed(feed)) {
                            FollowingFeedRow(feed: feed, showsDomain: false)
                        }
                        .contextMenu {
                            FollowingFeedContextMenu(
                                feed: feed,
                                feedForEditSheet: $feedForEditSheet,
                                feedToDelete: $feedToDelete
                            )
                        }
                        .id(feed.id)
                    }
                } header: {
                    HStack {
                        Text(section.localizedTitle)
                        Spacer()
                        Button {
                            selectedDestination = .section(section)
                        } label: {
                            Text(String(localized: "Sidebar.SeeAll", table: "Feeds"))
                                .textCase(nil)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    private var sortedLists: [FeedList] {
        feedManager.lists.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func feedsForSection(_ section: FeedSection) -> [Feed] {
        let feeds = feedManager.feeds.filter { $0.feedSection == section }
        if section == .feeds {
            return feeds
        }
        return feeds.sorted {
            let domainCompare = $0.domain.localizedStandardCompare($1.domain)
            if domainCompare != .orderedSame { return domainCompare == .orderedAscending }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        Section {
            Label("Tabs.Profile", systemImage: "person.crop.circle")
                .tag(SidebarDestination.more)
        }
    }

    @ViewBuilder
    private var addMenu: some View {
        Menu {
            Button {
                showingAddFeed = true
            } label: {
                Label(String(localized: "Sidebar.AddFeed", table: "Feeds"),
                      systemImage: "dot.radiowaves.up.forward")
            }
            Button {
                showingNewList = true
            } label: {
                Label(String(localized: "Sidebar.CreateList", table: "Feeds"),
                      systemImage: "square.fill.text.grid.1x2")
            }
        } label: {
            Image(systemName: "plus")
        }
    }
}

private struct SidebarUnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.tertiary)
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
    }
}

private struct IPadSidebarListContextMenu: View {

    let list: FeedList
    @Binding var listToEdit: FeedList?
    @Binding var listForRules: FeedList?
    @Binding var listToDelete: FeedList?

    var body: some View {
        Button {
            listToEdit = list
        } label: {
            Label(String(localized: "ListMenu.Edit", table: "Lists"), systemImage: "pencil")
        }
        Button {
            listForRules = list
        } label: {
            Label(String(localized: "ListMenu.Rules", table: "Lists"),
                  systemImage: "list.bullet.rectangle")
        }
        Divider()
        Button(role: .destructive) {
            listToDelete = list
        } label: {
            Label(String(localized: "ListMenu.Delete", table: "Lists"), systemImage: "trash")
        }
    }
}
