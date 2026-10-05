import SwiftUI

// swiftlint:disable:next type_name
struct iCloudSettingsPane: View {

    var body: some View {
        SettingsForm {
            iCloudSyncSettingsRows()
            SettingsGroupSpacer()
            iCloudBackupSettingsRows()
        }
    }
}
