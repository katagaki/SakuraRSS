import SwiftUI

struct StorageSettingsSection: View {

    let deviceStats: DeviceStorageStats?

    var body: some View {
        Section {
            StorageBarSection(deviceStats: deviceStats)
        } header: {
            Text(String(localized: "Section.Storage", table: "Settings"))
        }
    }
}
