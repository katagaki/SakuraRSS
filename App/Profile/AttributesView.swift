import SwiftUI
import Hanami

struct AttributesView: View {

    var body: some View {
        List {
            ForEach(Dependency.all) { dependency in
                Section {
                    Text(dependency.licenseText)
                        .font(.caption)
                        .monospaced()
                        .listRowBackground(Color.clear)
                } header: {
                    Text(dependency.name)
                }
            }
        }
        .listStyle(.grouped)
        .navigationTitle("More.Attribution")
        .navigationBarTitleDisplayMode(.inline)
        .sakuraBackground()
    }
}
