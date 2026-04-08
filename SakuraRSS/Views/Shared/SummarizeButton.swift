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
                    String(localized: showingSummary
                           ? "Article.ShowOriginal"
                           : "Article.ShowSummary"),
                    systemImage: showingSummary
                        ? "doc.plaintext" : "apple.intelligence"
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
                    "Article.Summarize",
                    systemImage: "apple.intelligence"
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
