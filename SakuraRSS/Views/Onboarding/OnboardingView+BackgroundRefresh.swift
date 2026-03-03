import SwiftUI

extension OnboardingView {

    var backgroundRefreshStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "arrow.trianglehead.clockwise",
                    title: String(localized: "Onboarding.Step.BackgroundRefresh.Title"),
                    description: String(localized: "Onboarding.Step.BackgroundRefresh.Description")
                )

                VStack(spacing: 0) {
                    Toggle(String(localized: "Settings.BackgroundRefresh"), isOn: $backgroundRefreshEnabled)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                }
                .background(.regularMaterial, in: .capsule)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            continueButton { advanceStep() }
        }
    }
}
