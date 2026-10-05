import Hanami
import SwiftUI
@preconcurrency import Translation

/// The Translate and Summarize actions iOS keeps in its viewers' menus, as
/// buttons under the content's header.
struct ContentAssistBar: View {

    @Bindable var assistant: ContentAssistant
    let source: String?

    var body: some View {
        HStack(spacing: 8) {
            if !assistant.showingTranslation {
                Button { assistant.toggleTranslation() } label: {
                    Label(translateLabel, systemImage: "translate")
                }
                .disabled(assistant.isTranslating)
            }
            if assistant.canSummarize && !assistant.showingSummary {
                Button { assistant.toggleSummary(source: source) } label: {
                    Label(summarizeLabel, systemImage: "text.line.3.summary")
                }
                .disabled(assistant.isSummarizing)
            }
            if assistant.showingSummary || assistant.showingTranslation {
                Button { assistant.showOriginal() } label: {
                    Label(text("Article.ShowOriginal"), systemImage: "arrow.uturn.backward")
                }
            }
            if assistant.isWorking {
                ProgressView().controlSize(.small)
                Text(text(assistant.isTranslating ? "Article.Translating" : "Article.Summarizing"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(source == nil)
        .translationTask(assistant.translationConfiguration) { session in
            await assistant.translate(with: session, source: source)
        }
        .alert(text("Article.Summarize.Error"), isPresented: Binding(
            get: { assistant.summaryError != nil },
            set: { if !$0 { assistant.summaryError = nil } }
        )) {
            Button("Shared.OK") {}
        } message: {
            Text(assistant.summaryError ?? "")
        }
    }

    private var translateLabel: String {
        if assistant.showingSummary {
            return text("Article.TranslateSummary")
        }
        if assistant.translatedText != nil {
            return text("Article.ShowTranslation")
        }
        return text("Article.Translate")
    }

    private var summarizeLabel: String {
        if assistant.showingTranslation {
            return text("Article.SummarizeTranslation")
        }
        if assistant.summary != nil || assistant.hasCachedSummary {
            return text("Article.ShowSummary")
        }
        return text("Article.Summarize")
    }

    private func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: "Articles")
    }
}
