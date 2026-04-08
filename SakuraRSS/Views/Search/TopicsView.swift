import SwiftUI

struct TopicsView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var topics: [(name: String, count: Int)] = []
    @Namespace private var cardZoom

    var body: some View {
        Group {
            if topics.isEmpty {
                ContentUnavailableView {
                    Label("Topics.Empty", systemImage: "tag")
                } description: {
                    Text("Topics.Empty.Description")
                }
            } else {
                List(topics, id: \.name) { topic in
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
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Topics.Title")
        .task {
            await loadTopics()
        }
    }

    private func loadTopics() async {
        let db = DatabaseManager.shared
        await Task.detached {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            let results = (try? db.topEntities(
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
