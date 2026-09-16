import SwiftUI
import Hanami

struct BookmarkDetailSheet: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.dismiss) private var dismiss

    let article: Article

    @State private var titleText = ""
    @State private var hasLoaded = false

    private var trimmedTitle: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isRenamed: Bool {
        !trimmedTitle.isEmpty && trimmedTitle != article.title
    }

    var body: some View {
        NavigationStack {
            List {
                titleSection
                BookmarkTagEditorSection(article: article)
                BookmarkPreviewSection(article: article)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "BookmarkDetail.Title", table: "Articles"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private var titleSection: some View {
        Section {
            TextField(String(localized: "BookmarkDetail.TitlePlaceholder", table: "Articles"),
                      text: $titleText, axis: .vertical)
                .lineLimit(1...4)
            if isRenamed {
                Button {
                    titleText = article.title
                } label: {
                    Label(String(localized: "BookmarkDetail.RestoreTitle", table: "Articles"),
                          systemImage: "arrow.uturn.backward")
                }
            }
        } header: {
            Text(String(localized: "BookmarkDetail.TitleHeader", table: "Articles"))
        } footer: {
            Text(isRenamed
                 ? String(localized: "BookmarkDetail.OriginalTitle.\(article.title)", table: "Articles")
                 : String(localized: "BookmarkDetail.TitleFooter", table: "Articles"))
        }
    }

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        titleText = article.displayTitle
    }

    private func save() {
        feedManager.setBookmarkCustomTitle(isRenamed ? trimmedTitle : nil, forArticleID: article.id)
        dismiss()
    }
}
