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
            sectionsAndAllArticles
            bookmarksSection
            insightsSection
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
        }
        .sheet(isPresented: $showingNewList) {
            ListEditSheet(list: nil)
                .environment(feedManager)
                .interactiveDismissDisabled()
        }
        .sheet(item: $feedForEditSheet) { wrapper in
            FeedEditSheet(feedID: wrapper.id)
                .environment(feedManager)
        }
    }

    @ViewBuilder
    private var sectionsAndAllArticles: some View {
        Section {
            Label("Shared.AllArticles", systemImage: "square.stack")
                .tag(SidebarDestination.allArticles)
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

    @ViewBuilder
    private var bookmarksSection: some View {
        Section {
            Label("Tabs.Bookmarks", systemImage: "bookmark")
                .tag(SidebarDestination.bookmarks)
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        if contentInsightsEnabled {
            Section {
                Label(String(localized: "Topics.Title", table: "Articles"), systemImage: "number")
                    .tag(SidebarDestination.topics)
                Label(String(localized: "People.Title", table: "Articles"), systemImage: "person.2")
                    .tag(SidebarDestination.people)
            }
        }
    }

    @ViewBuilder
    private var listsSection: some View {
        if !feedManager.lists.isEmpty {
            Section("Tabs.Lists") {
                ForEach(feedManager.lists) { list in
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
        Section(String(localized: "Sidebar.Following", table: "Feeds")) {
            ForEach(feedManager.feeds) { feed in
                NavigationLink(value: SidebarDestination.feed(feed)) {
                    FeedRowView(feed: feed)
                }
                .contextMenu {
                    FeedRowContextMenu(
                        feed: feed,
                        feedForEditSheet: $feedForEditSheet,
                        feedToDelete: $feedToDelete
                    )
                }
                .id(feed.id)
            }
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
