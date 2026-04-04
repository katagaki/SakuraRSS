import SwiftUI

extension OnboardingView {

    var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(.sakuraIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 80)
                    Text("Onboarding.Welcome.Title.\(appName)")
                        .font(.largeTitle.bold())
                }

                VStack(alignment: .leading, spacing: 24) {
                    featureRow(
                        icon: "newspaper.fill",
                        title: String(localized: "Onboarding.Feature.Feeds"),
                        description: String(localized: "Onboarding.Feature.Feeds.Description")
                    )
                    featureRow(
                        icon: "rectangle.grid.2x2.fill",
                        title: String(localized: "Onboarding.Feature.ViewStyles"),
                        description: String(localized: "Onboarding.Feature.ViewStyles.Description")
                    )
                    featureRow(
                        icon: "headphones",
                        title: String(localized: "Onboarding.Feature.Podcasts"),
                        description: String(localized: "Onboarding.Feature.Podcasts.Description")
                    )
                    featureRow(
                        icon: "apple.intelligence",
                        title: String(localized: "Onboarding.Feature.Summaries"),
                        description: String(localized: "Onboarding.Feature.Summaries.Description")
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            continueButton { advanceStep() }
                .padding(.bottom, isIPad ? 20 : 0)
        }
    }
}
