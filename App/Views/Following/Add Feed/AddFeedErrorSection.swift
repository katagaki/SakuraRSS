import SwiftUI

struct AddFeedErrorSection: View {

    let errorMessage: String
    let showPetalGenerate: Bool
    let onGeneratePetal: () -> Void

    var body: some View {
        Section {
            Text(errorMessage)
                .foregroundStyle(.red)
        }

        if showPetalGenerate {
            Section {
                Button {
                    onGeneratePetal()
                } label: {
                    Label(String(localized: "AddFeed.Generate", table: "Petal"), systemImage: "leaf.fill")
                }
            } footer: {
                Text(String(localized: "AddFeed.GenerateFooter", table: "Petal"))
            }
        }
    }
}
