import SwiftUI
import FoundationModels
import Hanami

/// Apple Intelligence summary section. Renders as a horizontally paginated
/// headline carousel; tapping a card opens the contributing articles list.
struct SummarySection: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.navigateToSummaryHeadline) private var navigateToHeadline

    let kind: SummaryCardKind
    @Binding var hasSummary: Bool
    var isVisible: Binding<Bool>?
    var refreshTrigger: Int

    @AppStorage private var isEnabled: Bool
    @AppStorage private var forceVisible: Bool

    @State var headlines: [SummaryHeadline] = []
    @State var isGenerating = false
    @State var hasGenerated = false
    @State var generationFailed = false
    @State var generationError: String?
    @State var cachedIsPartial: Bool = false
    @State var cachedArticleCountAtGeneration: Int = 0
    @State private var deferredForLowPowerMode = false
    @State private var articleCount: Int = 0

    init(
        kind: SummaryCardKind,
        hasSummary: Binding<Bool>,
        isVisible: Binding<Bool>? = nil,
        refreshTrigger: Int = 0
    ) {
        self.kind = kind
        self._hasSummary = hasSummary
        self.isVisible = isVisible
        self.refreshTrigger = refreshTrigger
        self._isEnabled = AppStorage(wrappedValue: false, kind.enabledStorageKey)
        self._forceVisible = AppStorage(wrappedValue: false, kind.forceVisibleStorageKey)
    }

    init(
        kind: SummaryCardKind,
        hasSummary: Binding<Bool>,
        flatStyle _: Bool,
        isVisible: Binding<Bool>? = nil,
        refreshTrigger: Int = 0
    ) {
        self.init(
            kind: kind,
            hasSummary: hasSummary,
            isVisible: isVisible,
            refreshTrigger: refreshTrigger
        )
    }

    private var isSupported: Bool {
        SystemLanguageModel.default.availability == .available
    }

    private var canGenerate: Bool {
        if forceVisible { return isSupported }
        return isEnabled && isSupported && kind.isInTimeWindow(Date())
    }

    private var shouldShow: Bool {
        if forceVisible { return true }
        return canGenerate && articleCount > 0 && (hasGenerated || isGenerating)
    }

    var body: some View {
        ZStack {
            if shouldShow {
                summaryCard
                    .transition(.opacity)
                    .animation(.smooth.speed(2.0), value: isGenerating)
                    .animation(.smooth.speed(2.0), value: headlines)
                    .animation(.smooth.speed(2.0), value: generationFailed)
                    .animation(.smooth.speed(2.0), value: deferredForLowPowerMode)
            }
        }
        .task {
            await loadOrGenerateHeadlines()
        }
        .task(id: feedManager.dataRevision) {
            let count = kind.articles(in: feedManager).count
            log("Summary", "kind=\(kind) revision=\(feedManager.dataRevision) count=\(count)")
            withAnimation(.smooth.speed(2.0)) {
                articleCount = count
            }
            maybeAutoRegenerate(count: count)
        }
        .onChange(of: feedManager.isLoading) { _, nowLoading in
            guard !nowLoading, !hasGenerated, !isGenerating else { return }
            Task { await loadOrGenerateHeadlines() }
        }
        .onAppear { isVisible?.wrappedValue = shouldShow }
        .onChange(of: shouldShow) { _, newValue in isVisible?.wrappedValue = newValue }
        .onChange(of: refreshTrigger) { _, newValue in
            guard newValue > 0, canGenerate, !isGenerating else { return }
            isGenerating = true
            Task { await regenerateHeadlines() }
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
                .padding(.horizontal)
            content
            footer
                .padding(.horizontal)
        }
        .background {
            appleIntelligenceMeshBackground
        }
    }

    /// Apple Intelligence 4-color mesh gradient, vertically masked so it
    /// fades clear -> visible -> clear behind the section.
    private var appleIntelligenceMeshBackground: some View {
        MeshGradient(
            width: 2,
            height: 2,
            points: [
                [0.0, 0.0], [1.0, 0.0],
                [0.0, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(red: 0.94, green: 0.45, blue: 0.25),
                Color(red: 0.90, green: 0.35, blue: 0.60),
                Color(red: 0.55, green: 0.35, blue: 0.80),
                Color(red: 0.40, green: 0.45, blue: 0.95)
            ]
        )
        .opacity(0.18)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.35),
                    .init(color: .black, location: 0.65),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Text(kind.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 4) {
            Image(systemName: "apple.intelligence")
                .symbolRenderingMode(.multicolor)
                .font(.caption2)
            Text(String(localized: "AppleIntelligence.VerifyImportantInformation", table: "Settings"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !headlines.isEmpty {
            SummaryHeadlineCarousel(headlines: headlines) { headline in
                navigateToHeadline?(
                    SummaryHeadlineDestination(
                        title: headline.headline,
                        articleIDs: headline.articleIDs
                    )
                )
            }
        } else {
            placeholderFrame { placeholderContent }
        }
    }

    /// Inner placeholder content. Returning a non-zero-size view in every
    /// branch (including the brief idle window between state flips) keeps
    /// the section from collapsing to height 0 mid-transition, which would
    /// otherwise make TodayView's scroll offset jump.
    @ViewBuilder
    private var placeholderContent: some View {
        if isGenerating {
            VStack(spacing: 10) {
                ProgressView()
                Text(kind.generating)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        } else if deferredForLowPowerMode {
            Text(kind.lowPowerModePrompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        } else if generationFailed {
            ContentUnavailableView {
                Label(
                    String(localized: "SummaryHeadlines.NoHeadlines.Title", table: "Home"),
                    systemImage: "newspaper"
                )
            } description: {
                Text(String(localized: "SummaryHeadlines.NoHeadlines.Description", table: "Home"))
            }
        } else {
            ProgressView()
        }
    }

    /// Reserves the same 4:3 footprint as a populated card so the height
    /// doesn't change when the carousel materializes. On Mac Catalyst, uses
    /// a fixed height instead since 4:3 of a wide column is unreasonably tall.
    @ViewBuilder
    private func placeholderFrame<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        #if targetEnvironment(macCatalyst)
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay {
                content()
            }
        #else
        Color.clear
            .containerRelativeFrame(.horizontal) { value, _ in
                max(0, value - 32)
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                content()
            }
        #endif
    }

}

private extension SummarySection {

    /// Regenerates when the cached run was partial and enough new articles have
    /// since arrived. Spawns its own task so it is never cancelled by the
    /// data-revision observer restarting.
    func maybeAutoRegenerate(count: Int) {
        guard hasGenerated, cachedIsPartial, !isGenerating,
              !feedManager.isLoading,
              count >= cachedArticleCountAtGeneration + 3 else { return }
        log(
            "Summary",
            "auto-regen: partial cache + \(count - cachedArticleCountAtGeneration) more articles"
        )
        isGenerating = true
        Task { await regenerateHeadlines() }
    }

    func loadOrGenerateHeadlines() async {
        guard !hasGenerated, !isGenerating, canGenerate else { return }
        let today = Date()

        if loadCachedHeadlines(for: today) { return }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            deferredForLowPowerMode = true
            hasGenerated = true
            return
        }

        // No wait/poll: generate only once the feed has finished loading.
        // While a refresh is in flight, the loading-completion observer (or the
        // end of the swipe-refresh pipeline) drives generation instead.
        guard !feedManager.isLoading else { return }
        isGenerating = true
        await generateHeadlines(for: today)
    }

    func loadCachedHeadlines(for date: Date) -> Bool {
        guard let cached = try? DatabaseManager.shared.cachedSummaryHeadlines(
            ofType: kind.cacheType,
            for: date
        ), !cached.headlines.isEmpty else { return false }
        headlines = cached.headlines
        cachedIsPartial = cached.partialGeneration
        cachedArticleCountAtGeneration = cached.articleCountAtGeneration
        hasGenerated = true
        hasSummary = true
        return true
    }

    func regenerateHeadlines() async {
        let today = Date()
        try? DatabaseManager.shared.clearCachedSummaryHeadlines(ofType: kind.cacheType, for: today)
        withAnimation(.smooth.speed(2.0)) {
            headlines = []
            generationFailed = false
            generationError = nil
            deferredForLowPowerMode = false
            cachedIsPartial = false
            cachedArticleCountAtGeneration = 0
        }
        await generateHeadlines(for: today)
    }
}
