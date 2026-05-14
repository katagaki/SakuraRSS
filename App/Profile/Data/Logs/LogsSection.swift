import SwiftUI
import Hanami

struct LogsSection: View {

    var body: some View {
        Section {
            NavigationLink {
                LogsView()
            } label: {
                Text(String(localized: "Section.Logs", table: "Settings"))
            }
        } footer: {
            Text(String(localized: "Logs.Footer", table: "DataManagement"))
        }
    }
}
