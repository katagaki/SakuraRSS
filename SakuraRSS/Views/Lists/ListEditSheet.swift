import SwiftUI

struct ListEditSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let list: FeedList?

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedDisplayStyle: String?
    @State private var selectedFeedIDs: Set<Int64>

    private var isEditing: Bool { list != nil }

    private var nameAlreadyExists: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return feedManager.lists.contains { existing in
            existing.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
            && existing.id != (list?.id ?? -1)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !nameAlreadyExists
    }

    init(list: FeedList?) {
        self.list = list
        _name = State(initialValue: list?.name ?? "")
        _selectedIcon = State(initialValue: list?.icon ?? ListIcon.newspaper.rawValue)
        _selectedDisplayStyle = State(initialValue: list?.displayStyle)
        _selectedFeedIDs = State(initialValue: [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "ListEdit.NamePlaceholder"), text: $name)
                    if nameAlreadyExists {
                        Text("ListEdit.NameExists")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(String(localized: "ListEdit.Icon")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5),
                              spacing: 16) {
                        ForEach(ListIcon.allCases) { icon in
                            Button {
                                selectedIcon = icon.rawValue
                            } label: {
                                Image(systemName: icon.rawValue)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        selectedIcon == icon.rawValue
                                            ? AnyShapeStyle(.tint.opacity(0.2))
                                            : AnyShapeStyle(.clear)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon.rawValue)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(String(localized: "ListEdit.DisplayStyle")) {
                    Picker(String(localized: "ListEdit.DisplayStyle"),
                           selection: $selectedDisplayStyle) {
                        Text("ListEdit.DisplayStyle.Default")
                            .tag(String?.none)
                        ForEach(FeedDisplayStyle.allCases.filter {
                            $0 != .video && $0 != .podcast
                        }, id: \.self) { style in
                            Text(style.rawValue.capitalized)
                                .tag(Optional(style.rawValue))
                        }
                    }
                    .labelsHidden()
                }

                Section(String(localized: "ListEdit.Feeds")) {
                    if feedManager.feeds.isEmpty {
                        Text("ListEdit.Feeds.Empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(feedManager.feeds) { feed in
                            Button {
                                if selectedFeedIDs.contains(feed.id) {
                                    selectedFeedIDs.remove(feed.id)
                                } else {
                                    selectedFeedIDs.insert(feed.id)
                                }
                            } label: {
                                HStack {
                                    FeedRowView(feed: feed)
                                    Spacer()
                                    if selectedFeedIDs.contains(feed.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(isEditing
                             ? String(localized: "ListEdit.Title.Edit")
                             : String(localized: "ListEdit.Title.New"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let list {
                    selectedFeedIDs = feedManager.feedIDs(for: list)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let list {
            feedManager.updateList(list, name: trimmedName, icon: selectedIcon,
                                   displayStyle: selectedDisplayStyle)
            // Update feed membership
            let currentIDs = feedManager.feedIDs(for: list)
            for id in selectedFeedIDs where !currentIDs.contains(id) {
                if let feed = feedManager.feedsByID[id] {
                    feedManager.addFeedToList(list, feed: feed)
                }
            }
            for id in currentIDs where !selectedFeedIDs.contains(id) {
                if let feed = feedManager.feedsByID[id] {
                    feedManager.removeFeedFromList(list, feed: feed)
                }
            }
        } else {
            if let _ = try? feedManager.createList(name: trimmedName, icon: selectedIcon) {
                // Newly created list — assign feeds
                if let newList = feedManager.lists.last {
                    for id in selectedFeedIDs {
                        if let feed = feedManager.feedsByID[id] {
                            feedManager.addFeedToList(newList, feed: feed)
                        }
                    }
                    if let ds = selectedDisplayStyle {
                        feedManager.updateList(newList, name: trimmedName,
                                               icon: selectedIcon, displayStyle: ds)
                    }
                }
            }
        }
        dismiss()
    }
}
