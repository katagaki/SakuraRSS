import SwiftUI
import Hanami

struct DataSettingsSection: View {

    var body: some View {
        Section {
            NavigationLink {
                iCloudSyncView()
            } label: {
                Text(String(localized: "iCloudSync.Title", table: "DataManagement"))
            }
            NavigationLink {
                iCloudBackupView()
            } label: {
                Text(String(localized: "iCloudBackup.Title", table: "DataManagement"))
            }
        }
    }
}
