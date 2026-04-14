import PDFKit
import SwiftUI

/// Identifier passed to `.navigationDestination(item:)` for the arXiv PDF
/// viewer. Using a dedicated type (rather than `URL`) avoids colliding with
/// the article detail view's other URL-typed navigation destinations.
struct ArXivPDFReference: Identifiable, Hashable {
    let url: URL
    let title: String
    var id: URL { url }
}

/// In-app PDF viewer used for arXiv papers. Downloads the PDF with the
/// standard Sakura user agent and renders it with PDFKit.
struct ArXivPDFViewerView: View {

    let url: URL
    let title: String

    @State private var document: PDFDocument?
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let document {
                PDFKitView(document: document)
                    .ignoresSafeArea(edges: .vertical)
            } else if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(loadError)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if document != nil {
                    ShareLink(item: url) {
                        Label("Article.Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task(id: url) {
            await loadPDF()
        }
    }

    private func loadPDF() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let request = URLRequest.sakura(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                loadError = String(localized: "ArXiv.PDF.LoadFailed")
                return
            }
            if let doc = PDFDocument(data: data) {
                document = doc
            } else {
                loadError = String(localized: "ArXiv.PDF.LoadFailed")
            }
        } catch {
            loadError = String(localized: "ArXiv.PDF.LoadFailed")
        }
    }
}

private struct PDFKitView: UIViewRepresentable {

    let document: PDFDocument

    func makeUIView(context _: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.usePageViewController(false)
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context _: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
    }
}
