import SwiftUI
import Hanami

struct BookmarkExportSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var format: BookmarkExportFormat = .json
    @State private var items: [ExportedBookmark] = []
    @State private var isLoading = true

    private var output: String {
        BookmarkExporter.export(
            items,
            as: format,
            unsortedFolderName: String(localized: "Bookmarks.Unsorted", table: "Articles")
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(String(localized: "BookmarksExport.Format", table: "Articles"), selection: $format) {
                    Text("JSON").tag(BookmarkExportFormat.json)
                    Text("CSV").tag(BookmarkExportFormat.csv)
                    Text("HTML").tag(BookmarkExportFormat.html)
                    Text("Markdown").tag(BookmarkExportFormat.markdown)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(16)

                Text(formatExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
            }
            .navigationTitle(String(localized: "BookmarksExport.Title", table: "Articles"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: output,
                        preview: SharePreview("bookmarks.\(format.fileExtension)")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isLoading || items.isEmpty)
                }
            }
            .task {
                items = await Task.detached {
                    (try? DatabaseManager.shared.exportableBookmarks()) ?? []
                }.value
                isLoading = false
            }
        }
    }

    private var formatExplanation: String {
        switch format {
        case .json: String(localized: "BookmarksExport.Format.JSON", table: "Articles")
        case .csv: String(localized: "BookmarksExport.Format.CSV", table: "Articles")
        case .html: String(localized: "BookmarksExport.Format.HTML", table: "Articles")
        case .markdown: String(localized: "BookmarksExport.Format.Markdown", table: "Articles")
        }
    }
}
