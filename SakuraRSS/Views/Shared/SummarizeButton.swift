import SwiftUI

struct SummarizeButton: View {

    var summarizedText: String?
    var hasCachedSummary: Bool
    var isSummarizing: Bool
    @Binding var showingSummary: Bool
    var onSummarize: () async -> Bool

    private var hasAvailableSummary: Bool {
        (summarizedText != nil || hasCachedSummary) && !isSummarizing
    }

    var body: some View {
        if hasAvailableSummary {
            Button {
                if summarizedText == nil {
                    Task {
                        let success = await onSummarize()
                        if success {
                            withAnimation(.smooth.speed(2.0)) {
                                showingSummary = true
                            }
                        }
                    }
                } else {
                    withAnimation(.smooth.speed(2.0)) {
                        showingSummary.toggle()
                    }
                }
            } label: {
                Label(
                    showingSummary
                        ? String(localized: "Article.ShowOriginal", table: "Articles")
                        : String(localized: "Article.ShowSummary", table: "Articles"),
                    systemImage: showingSummary
                        ? "doc.plaintext" : "text.line.3.summary"
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        } else {
            Button {
                Task {
                    let success = await onSummarize()
                    if success {
                        withAnimation(.smooth.speed(2.0)) {
                            showingSummary = true
                        }
                    }
                }
            } label: {
                Label(
                    String(localized: "Article.Summarize", table: "Articles"),
                    systemImage: "text.line.3.summary"
                )
                .opacity(isSummarizing ? 0 : 1)
                .overlay {
                    if isSummarizing {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .disabled(isSummarizing)
            .animation(.smooth.speed(2.0), value: isSummarizing)
        }
    }
}
