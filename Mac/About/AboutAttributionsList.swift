import SwiftUI

/// The same attributions iOS lists, each license folded under its project.
struct AboutAttributionsList: View {

    @State private var expandedIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("More.Attribution")
                    .font(.headline)
                ForEach(Dependency.all) { dependency in
                    AboutAttributionRow(
                        dependency: dependency,
                        isExpanded: Binding(
                            get: { expandedIDs.contains(dependency.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedIDs.insert(dependency.id)
                                } else {
                                    expandedIDs.remove(dependency.id)
                                }
                            }
                        )
                    )
                    Divider()
                }
            }
            .padding(24)
        }
    }
}
