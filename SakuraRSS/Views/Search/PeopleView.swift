import SwiftUI

struct PeopleView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var people: [(name: String, count: Int)] = []

    var body: some View {
        Group {
            if people.isEmpty {
                ContentUnavailableView {
                    Label("People.Empty", systemImage: "person.2")
                } description: {
                    Text("People.Empty.Description")
                }
            } else {
                List(people, id: \.name) { person in
                    NavigationLink(value: EntityDestination(name: person.name, types: ["person"])) {
                        HStack {
                            Label(person.name, systemImage: "person")
                            Spacer()
                            Text("\(person.count)")
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
        .navigationTitle("People.Title")
        .task {
            await loadPeople()
        }
    }

    private func loadPeople() async {
        let db = DatabaseManager.shared
        await Task.detached {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            let results = (try? db.topEntities(
                type: "person",
                since: sevenDaysAgo,
                limit: 50
            )) ?? []
            await MainActor.run {
                people = results
            }
        }.value
    }
}
