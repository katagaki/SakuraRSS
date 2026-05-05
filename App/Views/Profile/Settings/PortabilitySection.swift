import SwiftUI
import UniformTypeIdentifiers

struct PortabilitySection: View {

    @Environment(FeedManager.self) var feedManager
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showImportModeChoice = false
    @State private var importedFileData: Data?
    @State private var alertMessage: String?
    @State private var showAlert = false

    var body: some View {
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
            handleImport(result: result)
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
    }

    private func handleImport(result: Result<[URL], Error>) {
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
