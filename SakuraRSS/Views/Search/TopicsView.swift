import SwiftUI

struct TopicsView: View {

    @Environment(FeedManager.self) var feedManager
    var filterText: String = ""
    @State private var topics: [(name: String, count: Int)] = []
    @Namespace private var cardZoom

    private var filteredTopics: [(name: String, count: Int)] {
        guard !filterText.isEmpty else { return topics }
        let needle = filterText.lowercased()
        return topics.filter { $0.name.lowercased().contains(needle) }
    }

    var body: some View {
        Group {
            if filteredTopics.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Topics.Empty", table: "Articles"), systemImage: "tag")
                } description: {
                    Text(String(localized: "Topics.Empty.Description", table: "Articles"))
                }
            } else {
                List(filteredTopics, id: \.name) { topic in
                    NavigationLink(value: EntityDestination(name: topic.name, types: ["organization", "place"])) {
                        HStack {
                            Label(topic.name, systemImage: "number")
                            Spacer()
                            Text("\(topic.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.tertiary)
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(String(localized: "Topics.Title", table: "Articles"))
        .task {
            await loadTopics()
        }
    }

    private func loadTopics() async {
        let database = DatabaseManager.shared
        await Task.detached {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            let results = (try? database.topEntities(
                types: ["organization", "place"],
                since: sevenDaysAgo,
                limit: 50
            )) ?? []
            await MainActor.run {
                topics = results
            }
        }.value
    }
}
