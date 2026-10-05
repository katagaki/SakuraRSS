import Hanami
import SwiftUI

struct WelcomeRestoreRow: View {

    let metadata: iCloudBackupManager.BackupMetadata

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "icloud.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Restore.Title", table: "Onboarding"))
                    .font(.body.weight(.semibold))
                // swiftlint:disable:next line_length
                Text(String(localized: "Restore.Description \(metadata.deviceName) \(metadata.date.formatted(date: .abbreviated, time: .shortened))", table: "Onboarding"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
