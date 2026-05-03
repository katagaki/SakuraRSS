import SwiftUI

extension OnboardingView {

    var appleIntelligenceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "apple.intelligence",
                    title: String(localized: "Step.AppleIntelligence.Title", table: "Onboarding"),
                    description: String(localized: "Step.AppleIntelligence.Description", table: "Onboarding")
                )

                VStack(spacing: 0) {
                    Toggle(String(localized: "Setting.AISummaries", table: "Onboarding"), isOn: Binding(
                        get: { todaysSummaryEnabled && whileYouSleptEnabled && afternoonBriefEnabled },
                        set: { newValue in
                            todaysSummaryEnabled = newValue
                            whileYouSleptEnabled = newValue
                            afternoonBriefEnabled = newValue
                        }
                    ))
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(.regularMaterial, in: .capsule)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                continueButton { advanceStep() }
                Button {
                    todaysSummaryEnabled = false
                    whileYouSleptEnabled = false
                    afternoonBriefEnabled = false
                    withAnimation(.smooth.speed(2.0)) {
                        currentStep = .addFeed
                    }
                } label: {
                    Text(String(localized: "Skip", table: "Onboarding"))
                        .fontWeight(.semibold)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .padding(.bottom, isIPad ? 20 : 8)
        }
    }
}
