import SwiftUI
import UniformTypeIdentifiers

struct DataSettingsSection: View {

    @Environment(FeedManager.self) var feedManager
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showImportModeChoice = false
    @State private var importedFileData: Data?
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showCleanupConfirmation = false
    @State private var selectedCleanupCutoff: Date?
    @State private var selectedCleanupLabel: String = ""
    @State private var isCleaningUp = false

    var body: some View {
        Group {
            Section {
                NavigationLink {
                    iCloudBackupView()
                } label: {
                    Text(String(localized: "iCloudBackup.Title", table: "DataManagement"))
                }
            }

            Section {
                HStack(spacing: 0) {
                    Button {
                        isExporting = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                            Text(String(localized: "ExportOPML", table: "DataManagement"))
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Divider()
                    Button {
                        isImporting = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
                            Text(String(localized: "ImportOPML", table: "DataManagement"))
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(EdgeInsets())
            } header: {
                Text(String(localized: "Section.Portability", table: "Settings"))
            } footer: {
                Text(String(localized: "OPML.Footer", table: "DataManagement"))
            }

            Section {
                Menu {
                    Button(String(localized: "Cleanup.Last24Hours", table: "DataManagement")) {
                        selectedCleanupCutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                        selectedCleanupLabel = String(localized: "Cleanup.Last24Hours", table: "DataManagement")
                        showCleanupConfirmation = true
                    }
                    Button(String(localized: "Cleanup.Last7Days", table: "DataManagement")) {
                        selectedCleanupCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                        selectedCleanupLabel = String(localized: "Cleanup.Last7Days", table: "DataManagement")
                        showCleanupConfirmation = true
                    }
                    Button(String(localized: "Cleanup.Last4Weeks", table: "DataManagement")) {
                        selectedCleanupCutoff = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())
                        selectedCleanupLabel = String(localized: "Cleanup.Last4Weeks", table: "DataManagement")
                        showCleanupConfirmation = true
                    }
                    Button(String(localized: "Cleanup.AllTime", table: "DataManagement")) {
                        selectedCleanupCutoff = nil
                        selectedCleanupLabel = String(localized: "Cleanup.AllTime", table: "DataManagement")
                        showCleanupConfirmation = true
                    }
                } label: {
                    HStack {
                        Text(String(localized: "Cleanup.Title", table: "DataManagement"))
                            .foregroundStyle(.red)
                        Spacer()
                        if isCleaningUp {
                            ProgressView()
                        }
                    }
                }
                .disabled(isCleaningUp)
            } header: {
                Text(String(localized: "Section.Storage", table: "Settings"))
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: OPMLDocument(content: feedManager.exportOPML()),
            contentType: .opml,
            defaultFilename: "SakuraRSS.opml"
        ) { result in
            switch result {
            case .success:
                alertMessage = String(localized: "Export.Success", table: "DataManagement")
                showAlert = true
            case .failure:
                alertMessage = String(localized: "Export.Error", table: "DataManagement")
                showAlert = true
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.opml, .xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    alertMessage = String(localized: "Import.Error", table: "DataManagement")
                    showAlert = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    importedFileData = data
                    showImportModeChoice = true
                } else {
                    alertMessage = String(localized: "Import.Error", table: "DataManagement")
                    showAlert = true
                }
            case .failure:
                alertMessage = String(localized: "Import.Error", table: "DataManagement")
                showAlert = true
            }
        }
        .alert(
            String(localized: "Import.ModeTitle", table: "DataManagement"),
            isPresented: $showImportModeChoice
        ) {
            Button(String(localized: "Import.Merge", table: "DataManagement")) {
                performImport(overwrite: false)
            }
            Button(String(localized: "Import.Overwrite", table: "DataManagement"), role: .destructive) {
                performImport(overwrite: true)
            }
            Button("Shared.Cancel", role: .cancel) {
                importedFileData = nil
            }
        } message: {
            Text(String(localized: "Import.ModeMessage", table: "DataManagement"))
        }
        .alert(String(localized: "Title", table: "DataManagement"), isPresented: $showAlert) {
            Button("Shared.OK") {}
        } message: {
            if let alertMessage {
                Text(alertMessage)
            }
        }
        .alert(
            String(localized: "Cleanup.ConfirmTitle", table: "DataManagement"),
            isPresented: $showCleanupConfirmation
        ) {
            Button(String(localized: "Cleanup.Confirm", table: "DataManagement"), role: .destructive) {
                isCleaningUp = true
                UIApplication.shared.isIdleTimerDisabled = true
                Task {
                    await feedManager.deleteArticlesAndVacuum(olderThan: selectedCleanupCutoff)
                    UIApplication.shared.isIdleTimerDisabled = false
                    isCleaningUp = false
                    alertMessage = String(localized: "Cleanup.Success", table: "DataManagement")
                    showAlert = true
                }
            }
            Button("Shared.Cancel", role: .cancel) {}
        } message: {
            Text(String(localized: "Cleanup.ConfirmMessage \(selectedCleanupLabel)", table: "DataManagement"))
        }
    }

    private func performImport(overwrite: Bool) {
        guard let data = importedFileData else { return }
        importedFileData = nil
        do {
            let count = try feedManager.importOPML(data: data, overwrite: overwrite)
            alertMessage = String(localized: "Import.Success \(count)", table: "DataManagement")
        } catch {
            alertMessage = String(localized: "Import.Error", table: "DataManagement")
        }
        showAlert = true
    }
}
