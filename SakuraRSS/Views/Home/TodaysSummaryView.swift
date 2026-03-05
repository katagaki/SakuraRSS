import SwiftUI
import FoundationModels

struct TodaysSummaryView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("TodaysSummary.Enabled") private var isEnabled: Bool = true
    @AppStorage("TodaysSummary.DismissedDate") private var dismissedDate: String = ""
    @AppStorage("ForceTodaysSummary") private var forceVisible: Bool = false

    @Binding var hasSummary: Bool

    @State private var summary: String = ""
    @State private var isGenerating = false
    @State private var hasGenerated = false
    @State private var isExpanded = false
    @State private var generationFailed = false
    @State private var generationError: String?

    private var isSupported: Bool {
        SystemLanguageModel.default.availability == .available
    }

    private var isHidden: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return dismissedDate == formatter.string(from: Date())
    }

    private var isEveningWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 21
    }

    private var shouldShow: Bool {
        if forceVisible {
            return !isHidden
        }
        return isEnabled && isSupported && isEveningWindow && !todayArticles.isEmpty && !isHidden
    }

    var body: some View {
        if shouldShow {
            summaryCard
                .transition(.opacity)
                .task {
                    if !hasGenerated {
                        await loadOrGenerateSummary()
                    }
                }
        }
    }

    private var todayArticles: [Article] {
        feedManager.todaySummaryArticles()
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "apple.intelligence")
                    .font(.title3)
                Text("TodaysSummary.Title")
                    .font(.headline)
                Spacer()
                Button {
                    Task {
                        await regenerateSummary()
                    }
                } label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isGenerating ? 0 : 1)
                .disabled(isGenerating)
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
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -8)
            }

            if isGenerating && summary.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("TodaysSummary.Generating")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if generationFailed {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TodaysSummary.Failed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let generationError {
                        Text(generationError)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else if !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .lineLimit(isExpanded ? nil : 4)
                    .contentTransition(.numericText())

                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded
                         ? String(localized: "TodaysSummary.ShowLess")
                         : String(localized: "TodaysSummary.ShowMore"))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.plain)
            }

            Text("AppleIntelligence.VerifyImportantInformation")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.black : Color.white)
                appleIntelligenceGradient
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(red: 0.85, green: 0.40, blue: 0.60).opacity(0.15), radius: 4, y: 2)
        .shadow(color: Color(red: 0.55, green: 0.35, blue: 0.80).opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal)
        .padding(.top, 8)
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

        if let cached = try? DatabaseManager.shared.cachedSummary(ofType: .todaysSummary, for: today) {
            summary = cached
            hasGenerated = true
            hasSummary = true
            return
        }

        // Wait for initial feed refresh to complete before generating
        while feedManager.isLoading {
            try? await Task.sleep(for: .milliseconds(200))
        }

        await generateSummary(for: today)
    }

    private func regenerateSummary() async {
        let today = Date()
        try? DatabaseManager.shared.clearCachedSummary(ofType: .todaysSummary, for: today)
        withAnimation(.smooth.speed(2.0)) {
            summary = ""
            isExpanded = false
            generationFailed = false
            generationError = nil
        }
        await generateSummary(for: today)
    }

    private func generateSummary(for date: Date) async {
        let articles = todayArticles
        guard !articles.isEmpty else { return }

        if articles.count < 5 {
            withAnimation(.smooth.speed(2.0)) {
                summary = String(localized: "TodaysSummary.TooFew")
            }
            hasSummary = true
            return
        }

        isGenerating = true
        defer {
            isGenerating = false
            hasGenerated = true
        }

        // Group articles by feed, preparing prompt data for each
        var feedDescriptions: [String] = []
        let groupedByFeed = Dictionary(grouping: articles, by: \.feedID)
        for (_, feedArticles) in groupedByFeed {
            let descriptions = feedArticles.prefix(30).map { article in
                let feed = feedManager.feed(forArticle: article)
                let source = feed?.title ?? ""
                let title = article.title
                let snippet = article.summary ?? ""
                return "[\(source)] \(title)\n\(snippet)"
            }.joined(separator: "\n\n")
            feedDescriptions.append(descriptions)
        }

        let instructions = String(localized: "TodaysSummary.PartialPrompt")

        do {
            // Summarize each feed concurrently, at most 3 at a time
            var feedSummaries: [String] = []

            try await withThrowingTaskGroup(of: String.self) { group in
                var index = 0

                while index < feedDescriptions.count && index < 3 {
                    let desc = feedDescriptions[index]
                    group.addTask {
                        let prompt = "\(instructions)\n\n\(desc)"
                        #if DEBUG
                        debugPrint("Per-feed prompt:\n\(prompt)")
                        #endif
                        let session = LanguageModelSession()
                        let response = try await session.respond(to: prompt)
                        return response.content
                    }
                    index += 1
                }

                for try await result in group {
                    feedSummaries.append(result)
                    if index < feedDescriptions.count {
                        let desc = feedDescriptions[index]
                        group.addTask {
                            let prompt = "\(instructions)\n\n\(desc)"
                            #if DEBUG
                            debugPrint("Per-feed prompt:\n\(prompt)")
                            #endif
                            let session = LanguageModelSession()
                            let response = try await session.respond(to: prompt)
                            return response.content
                        }
                        index += 1
                    }
                }
            }

            guard !feedSummaries.isEmpty else { return }

            // Combine per-feed summaries into one overall summary
            let finalContent: String
            if feedSummaries.count == 1 {
                finalContent = feedSummaries[0]
            } else {
                let combined = feedSummaries.joined(separator: "\n\n")
                let combineInstructions = String(localized: "TodaysSummary.CombinePrompt")
                let combinePrompt = "\(combineInstructions)\n\n\(combined)"

                #if DEBUG
                debugPrint("Combine prompt:\n\(combinePrompt)")
                #endif

                let session = LanguageModelSession()
                let response = try await session.respond(to: combinePrompt)
                finalContent = response.content
            }

            withAnimation(.smooth.speed(2.0)) {
                summary = finalContent
            }
            hasSummary = true
            try? DatabaseManager.shared.cacheSummary(finalContent, ofType: .todaysSummary, for: date)
        } catch {
            generationFailed = true
            generationError = error.localizedDescription
        }
    }
}
