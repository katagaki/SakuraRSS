import SwiftUI
import FoundationModels

struct WhileYouSleptView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("WhileYouSlept.Enabled") private var isEnabled: Bool = false
    @AppStorage("WhileYouSlept.DismissedDate") private var dismissedDate: String = ""
    @AppStorage("ForceWhileYouSlept") private var forceVisible: Bool = false

    @Binding var hasSummary: Bool

    @State var summary: String = ""
    @State var isGenerating = false
    @State var hasGenerated = false
    @State private var isExpanded = false
    @State var generationFailed = false

    private var isSupported: Bool {
        SystemLanguageModel.default.availability == .available
    }

    private var isHidden: Bool {
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

    private var isMorningWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 12
    }

    private var shouldShow: Bool {
        if forceVisible {
            return !isHidden
        }
        return isEnabled && isSupported && isMorningWindow && !overnightArticles.isEmpty && !isHidden
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

    private var overnightArticles: [Article] {
        feedManager.overnightArticles()
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "apple.intelligence")
                    .font(.title3)
                Text("WhileYouSlept.Title")
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
                        .contentShape(.rect)
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
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.trailing, -8)
            }

            if isGenerating && summary.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("WhileYouSlept.Generating")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if generationFailed {
                Text("WhileYouSlept.Failed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                    Text(isExpanded
                         ? String(localized: "WhileYouSlept.ShowLess")
                         : String(localized: "WhileYouSlept.ShowMore"))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.plain)
            }

            Text("AppleIntelligence.VerifyImportantInformation")
                .font(.caption)
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

        if let cached = try? DatabaseManager.shared.cachedSummary(ofType: .whileYouSlept, for: today) {
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
        try? DatabaseManager.shared.clearCachedSummary(ofType: .whileYouSlept, for: today)
        withAnimation(.smooth.speed(2.0)) {
            summary = ""
            isExpanded = false
            generationFailed = false
        }
        await generateSummary(for: today)
    }
}
