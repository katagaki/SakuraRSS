import SwiftUI

extension PodcastEpisodeView {

    var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                downloadButton
                if transcript != nil {
                    Button {
                        showingTranscript.toggle()
                    } label: {
                        Label("Podcast.Transcript", systemImage: "text.quote")
                    }
                }
                TranslateButton(
                    hasTranslation: hasTranslationForCurrentMode,
                    isTranslating: isTranslating,
                    showingTranslation: $showingTranslation,
                    onTranslate: { triggerTranslation() }
                )
                if isAppleIntelligenceAvailable {
                    SummarizeButton(
                        summarizedText: summarizedText,
                        hasCachedSummary: hasCachedSummary,
                        isSummarizing: isSummarizing,
                        showingSummary: $showingSummary,
                        onSummarize: {
                            await summarizeArticle()
                            return summarizedText != nil
                        }
                    )
                }
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        if let progress = downloadProgress {
            Button(role: .destructive) {
                PodcastDownloadManager.shared.cancelDownload(articleID: article.id)
            } label: {
                HStack(spacing: 6) {
                    ProgressView(value: progress.progress)
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                    Text("\(Int(progress.progress * 100))%")
                        .monospacedDigit()
                }
            }
        } else if isDownloaded {
            Menu {
                Button(role: .destructive) {
                    showingDeleteDownloadAlert = true
                } label: {
                    Label("Podcast.DeleteDownload", systemImage: "trash")
                }
            } label: {
                Label("Podcast.Downloaded", systemImage: "checkmark.circle.fill")
            }
            .alert("Podcast.DeleteDownload", isPresented: $showingDeleteDownloadAlert) {
                Button("Shared.Cancel", role: .cancel) { }
                Button("Podcast.DeleteDownload.Confirm", role: .destructive) {
                    try? PodcastDownloadManager.shared.deleteDownload(articleID: article.id)
                    isDownloaded = false
                    transcript = nil
                }
            }
        } else {
            Button {
                PodcastDownloadManager.shared.downloadEpisode(article: article)
            } label: {
                Label("Podcast.Download", systemImage: "arrow.down.circle")
            }
            .disabled(!canDownload)
        }
    }
}
