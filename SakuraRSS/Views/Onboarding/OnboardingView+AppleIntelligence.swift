import SwiftUI

extension OnboardingView {

    var appleIntelligenceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "apple.intelligence",
                    title: String(localized: "Onboarding.Step.AppleIntelligence.Title"),
                    description: String(localized: "Onboarding.Step.AppleIntelligence.Description")
                )

                VStack(spacing: 0) {
                    Toggle(String(localized: "Onboarding.Setting.AISummaries"), isOn: Binding(
                        get: { todaysSummaryEnabled && whileYouSleptEnabled },
                        set: { newValue in
                            todaysSummaryEnabled = newValue
                            whileYouSleptEnabled = newValue
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
                    withAnimation(.smooth.speed(2.0)) {
                        currentStep = .addFeed
                    }
                } label: {
                    Text("Onboarding.Skip")
                        .fontWeight(.semibold)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }
}
