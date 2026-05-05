import SwiftUI

struct DataSettingsSection: View {

    var body: some View {
        Section {
            NavigationLink {
                iCloudBackupView()
            } label: {
                Text(String(localized: "iCloudBackup.Title", table: "DataManagement"))
            }
        }
    }
}
