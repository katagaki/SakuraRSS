import Foundation

/// Identifies one of the three Apple Intelligence summary cards on Home.
/// Centralizes localization keys, AppStorage keys, time windows, article
/// providers, and cache types so `SummarySection` can render any of them.
enum SummaryCardKind {
    case todaysSummary
    case whileYouSlept
    case afternoonBrief

    var cacheType: DatabaseManager.SummaryCacheType {
        switch self {
        case .todaysSummary: .todaysSummary
        case .whileYouSlept: .whileYouSlept
        case .afternoonBrief: .afternoonBrief
        }
    }

    var enabledStorageKey: String {
        switch self {
        case .todaysSummary: "TodaysSummary.Enabled"
        case .whileYouSlept: "WhileYouSlept.Enabled"
        case .afternoonBrief: "AfternoonBrief.Enabled"
        }
    }

    var forceVisibleStorageKey: String {
        switch self {
        case .todaysSummary: "ForceTodaysSummary"
        case .whileYouSlept: "ForceWhileYouSlept"
        case .afternoonBrief: "ForceAfternoonBrief"
        }
    }

    func isInTimeWindow(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        switch self {
        case .todaysSummary: return hour >= 18
        case .whileYouSlept: return hour >= 6 && hour < 12
        case .afternoonBrief: return hour >= 12 && hour < 16
        }
    }

    func articles(in feedManager: FeedManager) -> [Article] {
        switch self {
        case .todaysSummary: feedManager.todaySummaryArticles()
        case .whileYouSlept: feedManager.overnightArticles()
        case .afternoonBrief: feedManager.afternoonBriefArticles()
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .todaysSummary: LocalizedStringResource("TodaysSummary.Title", table: "Home")
        case .whileYouSlept: LocalizedStringResource("WhileYouSlept.Title", table: "Home")
        case .afternoonBrief: LocalizedStringResource("AfternoonBrief.Title", table: "Home")
        }
    }

    var generating: LocalizedStringResource {
        switch self {
        case .todaysSummary: LocalizedStringResource("TodaysSummary.Generating", table: "Home")
        case .whileYouSlept: LocalizedStringResource("WhileYouSlept.Generating", table: "Home")
        case .afternoonBrief: LocalizedStringResource("AfternoonBrief.Generating", table: "Home")
        }
    }

    var lowPowerModePrompt: LocalizedStringResource {
        switch self {
        case .todaysSummary: LocalizedStringResource("TodaysSummary.LowPowerModePrompt", table: "Home")
        case .whileYouSlept: LocalizedStringResource("WhileYouSlept.LowPowerModePrompt", table: "Home")
        case .afternoonBrief: LocalizedStringResource("AfternoonBrief.LowPowerModePrompt", table: "Home")
        }
    }

    var failed: LocalizedStringResource {
        switch self {
        case .todaysSummary: LocalizedStringResource("TodaysSummary.Failed", table: "Home")
        case .whileYouSlept: LocalizedStringResource("WhileYouSlept.Failed", table: "Home")
        case .afternoonBrief: LocalizedStringResource("AfternoonBrief.Failed", table: "Home")
        }
    }

    var showMore: LocalizedStringResource {
        switch self {
        case .todaysSummary: LocalizedStringResource("TodaysSummary.ShowMore", table: "Home")
        case .whileYouSlept: LocalizedStringResource("WhileYouSlept.ShowMore", table: "Home")
        case .afternoonBrief: LocalizedStringResource("AfternoonBrief.ShowMore", table: "Home")
        }
    }

    var showLess: LocalizedStringResource {
        switch self {
        case .todaysSummary: LocalizedStringResource("TodaysSummary.ShowLess", table: "Home")
        case .whileYouSlept: LocalizedStringResource("WhileYouSlept.ShowLess", table: "Home")
        case .afternoonBrief: LocalizedStringResource("AfternoonBrief.ShowLess", table: "Home")
        }
    }

    var tooFew: LocalizedStringResource {
        switch self {
        case .todaysSummary: LocalizedStringResource("TodaysSummary.TooFew", table: "Home")
        case .whileYouSlept: LocalizedStringResource("WhileYouSlept.TooFew", table: "Home")
        case .afternoonBrief: LocalizedStringResource("AfternoonBrief.TooFew", table: "Home")
        }
    }

    /// Time-window phrase substituted into `SummaryHeadlines.SharedPrompt`
    /// at instruction-composition time.
    var timeWindowPhrase: LocalizedStringResource {
        switch self {
        case .todaysSummary:
            LocalizedStringResource("SummaryHeadlines.TimeWindow.Today", table: "Home")
        case .whileYouSlept:
            LocalizedStringResource("SummaryHeadlines.TimeWindow.Overnight", table: "Home")
        case .afternoonBrief:
            LocalizedStringResource("SummaryHeadlines.TimeWindow.ThisAfternoon", table: "Home")
        }
    }

}
