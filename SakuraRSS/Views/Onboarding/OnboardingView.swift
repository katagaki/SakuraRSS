import SwiftUI
import FoundationModels

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case backgroundRefresh
    case displayStyle
    case appleIntelligence
    case addFeed
}

struct OnboardingView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Display.DefaultStyle") var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Search.DisplayStyle") var searchDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("BackgroundRefresh.Enabled") var backgroundRefreshEnabled: Bool = true
    @AppStorage("TodaysSummary.Enabled") var todaysSummaryEnabled: Bool = false
    @AppStorage("WhileYouSlept.Enabled") var whileYouSleptEnabled: Bool = false

    @State var currentStep: OnboardingStep = .welcome
    @State var urlInput = ""
    @State var discoveredFeeds: [DiscoveredFeed] = []
    @State var isSearching = false
    @State var feedErrorMessage: String?
    @State var addedURLs: Set<String> = []
    @FocusState var isURLFieldFocused: Bool
    var onComplete: () -> Void

    var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sakura"
    }

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var body: some View {
        currentStepContent
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .overlay {
                ZStack(alignment: .topLeading) {
                    if currentStep != .welcome {
                        Button {
                            goBackStep()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.semibold))
                                .padding(4.0)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .padding()
                    }
                    Color.clear
                }
            }
        .interactiveDismissDisabled()
    }

    // MARK: - Step Content

    @ViewBuilder
    private var currentStepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .backgroundRefresh:
            backgroundRefreshStep
        case .displayStyle:
            displayStyleStep
        case .appleIntelligence:
            appleIntelligenceStep
        case .addFeed:
            addFeedStep
        }
    }

    // MARK: - Navigation

    func goBackStep() {
        withAnimation {
            switch currentStep {
            case .welcome:
                break
            case .backgroundRefresh:
                currentStep = .welcome
            case .displayStyle:
                currentStep = .backgroundRefresh
            case .appleIntelligence:
                currentStep = .displayStyle
            case .addFeed:
                if isAppleIntelligenceAvailable {
                    currentStep = .appleIntelligence
                } else {
                    currentStep = .displayStyle
                }
            }
        }
    }

    func advanceStep() {
        withAnimation {
            switch currentStep {
            case .welcome:
                currentStep = .backgroundRefresh
            case .backgroundRefresh:
                currentStep = .displayStyle
            case .displayStyle:
                if isAppleIntelligenceAvailable {
                    currentStep = .appleIntelligence
                } else {
                    todaysSummaryEnabled = false
                    whileYouSleptEnabled = false
                    currentStep = .addFeed
                }
            case .appleIntelligence:
                currentStep = .addFeed
            case .addFeed:
                onComplete()
            }
        }
    }
}
