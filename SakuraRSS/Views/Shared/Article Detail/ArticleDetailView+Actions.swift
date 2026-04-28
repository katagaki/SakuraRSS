import SwiftUI

extension ArticleDetailView: ArticleActions {

    var actionButtons: some View { sharedActionButtons }

    func performTranslate() {
        triggerTranslation()
    }

    func performSummarize() async {
        await summarizeArticle()
    }

    func performOpenArXivPDF() {
        guard let pdfURL = ArXivHelper.pdfURL(forArticleURL: article.url) else { return }
        arXivPDFReference = ArXivPDFReference(url: pdfURL, title: article.title)
    }

    func performOpenLink() {
        openArticleURL()
    }
}
