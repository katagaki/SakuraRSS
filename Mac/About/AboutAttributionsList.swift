import SwiftUI

/// The same attributions iOS lists, each license folded under its project.
struct AboutAttributionsList: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("More.Attribution")
                    .font(.headline)
                ForEach(Dependency.all) { dependency in
                    DisclosureGroup {
                        Text(dependency.licenseText)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    } label: {
                        HStack {
                            Text(dependency.name)
                            Spacer()
                            Text(dependency.license)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                }
            }
            .padding(24)
        }
    }
}
