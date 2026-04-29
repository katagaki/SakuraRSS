import SwiftUI

struct PeopleView: View {

    @Environment(FeedManager.self) var feedManager
    var filterText: String = ""
    @State private var people: [(name: String, count: Int)] = []

    private var filteredPeople: [(name: String, count: Int)] {
        guard !filterText.isEmpty else { return people }
        let needle = filterText.lowercased()
        return people.filter { $0.name.lowercased().contains(needle) }
    }

    var body: some View {
        Group {
            if filteredPeople.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "People.Empty", table: "Articles"), systemImage: "person.2")
                } description: {
                    Text(String(localized: "People.Empty.Description", table: "Articles"))
                }
            } else {
                List(filteredPeople, id: \.name) { person in
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
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(String(localized: "People.Title", table: "Articles"))
        .task {
            await loadPeople()
        }
    }

    private func loadPeople() async {
        let database = DatabaseManager.shared
        await Task.detached {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            let results = (try? database.topEntities(
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
