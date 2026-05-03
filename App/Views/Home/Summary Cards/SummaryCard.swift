import SwiftUI
import FoundationModels

/// Generic Apple Intelligence summary card. Drives appearance, gating, caching,
/// and generation off a `SummaryCardKind` so the three named cards
/// (`TodaysSummaryView`, `WhileYouSleptView`, `AfternoonBriefView`) stay thin.
struct SummaryCard: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.colorScheme) private var colorScheme

    let kind: SummaryCardKind
    @Binding var hasSummary: Bool
    /// When true, the card uses a flat material background and hides the
    /// dismiss button. Set to true when embedded inside the Today tab.
    var flatStyle: Bool
    /// Driven by `shouldShow` so parents (e.g. Today) can react when the card
    /// appears or disappears, without re-deriving its visibility logic.
    var isVisible: Binding<Bool>?

    @AppStorage private var isEnabled: Bool
    @AppStorage private var forceVisible: Bool
    @AppStorage private var dismissedDate: String

    @State var summary: String = ""
    @State var isGenerating = false
    @State var hasGenerated = false
    @State private var isExpanded = false
    @State var generationFailed = false
    @State var generationError: String?
    /// Auto-generation skipped under Low Power Mode; user must tap refresh.
    @State private var deferredForLowPowerMode = false
    /// Cached article count refreshed off the main thread when the feed data
    /// revision changes; lets `shouldShow` avoid a synchronous DB query on
    /// every body render.
    @State private var articleCount: Int = 0

    init(
        kind: SummaryCardKind,
        hasSummary: Binding<Bool>,
        flatStyle: Bool = false,
        isVisible: Binding<Bool>? = nil
    ) {
        self.kind = kind
        self._hasSummary = hasSummary
        self.flatStyle = flatStyle
        self.isVisible = isVisible
        self._isEnabled = AppStorage(wrappedValue: false, kind.enabledStorageKey)
        self._forceVisible = AppStorage(wrappedValue: false, kind.forceVisibleStorageKey)
        self._dismissedDate = AppStorage(
            wrappedValue: "",
            kind.dismissedDateStorageKey ?? "SummaryCard.UnusedDismissedDate"
        )
    }

    private var isSupported: Bool {
        SystemLanguageModel.default.availability == .available
    }

    private var isHidden: Bool {
        guard kind.supportsDismiss else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return dismissedDate == formatter.string(from: Date())
    }

    private var markdownAttributedString: AttributedString {
        let lines = summary.split(separator: "\n", omittingEmptySubsequences: false)
        var result = AttributedString()
        for (index, line) in lines.enumerated() {
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            if let parsed = try? AttributedString(markdown: String(line), options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )) {
                result.append(parsed)
            } else {
                result.append(AttributedString(String(line)))
            }
        }
        return result
    }

    private var shouldShow: Bool {
        if flatStyle || !kind.supportsDismiss {
            return forceVisible
                || (isEnabled && isSupported && kind.isInTimeWindow(Date()) && articleCount > 0)
        }
        if forceVisible {
            return !isHidden
        }
        return isEnabled && isSupported && kind.isInTimeWindow(Date())
            && articleCount > 0 && !isHidden
    }

    var body: some View {
        Group {
            if shouldShow {
                summaryCard
                    .transition(.opacity)
                    .animation(.smooth.speed(2.0), value: isGenerating)
                    .animation(.smooth.speed(2.0), value: summary)
                    .animation(.smooth.speed(2.0), value: generationFailed)
                    .animation(.smooth.speed(2.0), value: deferredForLowPowerMode)
                    .animation(.smooth.speed(2.0), value: isExpanded)
                    .task {
                        if !hasGenerated {
                            await loadOrGenerateSummary()
                        }
                    }
            }
        }
        .task(id: feedManager.dataRevision) {
            let count = kind.articles(in: feedManager).count
            withAnimation(.smooth.speed(2.0)) {
                articleCount = count
            }
        }
        .onAppear { isVisible?.wrappedValue = shouldShow }
        .onChange(of: shouldShow) { _, newValue in isVisible?.wrappedValue = newValue }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .padding(.top, -6)
            content
            Text(String(localized: "AppleIntelligence.VerifyImportantInformation", table: "Settings"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.black : Color.white)
                appleIntelligenceGradient
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .shadow(
            color: flatStyle ? .clear : Color(red: 0.85, green: 0.40, blue: 0.60).opacity(0.15),
            radius: flatStyle ? 0 : 4,
            y: flatStyle ? 0 : 2
        )
        .shadow(
            color: flatStyle ? .clear : Color(red: 0.55, green: 0.35, blue: 0.80).opacity(0.1),
            radius: flatStyle ? 0 : 8,
            y: flatStyle ? 0 : 4
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.intelligence")
                .font(.title3)
            Text(kind.title)
                .font(.headline)
            Spacer()
            Button {
                Task { await regenerateSummary() }
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .opacity(isGenerating ? 0 : 1)
            .disabled(isGenerating)
            if kind.supportsDismiss && !flatStyle {
                Button {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    withAnimation(.smooth.speed(2.0)) {
                        dismissedDate = formatter.string(from: Date())
                        forceVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.trailing, -16)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isGenerating && summary.isEmpty {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(kind.generating)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if deferredForLowPowerMode && summary.isEmpty {
            Text(kind.lowPowerModePrompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if generationFailed {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.failed)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let generationError {
                    Text(generationError)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } else if !summary.isEmpty {
            Text(markdownAttributedString)
                .font(.subheadline)
                .lineLimit(isExpanded ? nil : 4)
                .contentTransition(.numericText())

            Button {
                withAnimation(.smooth.speed(2.0)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(isExpanded ? kind.showLess : kind.showMore)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .buttonStyle(.plain)
        }
    }

    private var appleIntelligenceGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(red: 0.94, green: 0.45, blue: 0.25),
                Color(red: 0.90, green: 0.35, blue: 0.50),
                Color(red: 0.70, green: 0.30, blue: 0.70),
                Color(red: 0.95, green: 0.55, blue: 0.30),
                Color(red: 0.85, green: 0.40, blue: 0.60),
                Color(red: 0.55, green: 0.35, blue: 0.80),
                Color(red: 0.98, green: 0.70, blue: 0.30),
                Color(red: 0.60, green: 0.45, blue: 0.85),
                Color(red: 0.40, green: 0.40, blue: 0.90)
            ]
        )
        .opacity(0.3)
    }

    private func loadOrGenerateSummary() async {
        let today = Date()

        if let cached = try? DatabaseManager.shared.cachedSummary(ofType: kind.cacheType, for: today) {
            summary = cached
            hasGenerated = true
            hasSummary = true
            return
        }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            deferredForLowPowerMode = true
            hasGenerated = true
            return
        }

        while feedManager.isLoading {
            try? await Task.sleep(for: .milliseconds(200))
        }

        await generateSummary(for: today)
    }

    private func regenerateSummary() async {
        let today = Date()
        try? DatabaseManager.shared.clearCachedSummary(ofType: kind.cacheType, for: today)
        withAnimation(.smooth.speed(2.0)) {
            summary = ""
            isExpanded = false
            generationFailed = false
            generationError = nil
            deferredForLowPowerMode = false
        }
        await generateSummary(for: today)
    }
}
