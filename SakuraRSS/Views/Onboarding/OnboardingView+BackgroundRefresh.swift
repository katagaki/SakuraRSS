import SwiftUI

extension OnboardingView {

    var backgroundRefreshStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "arrow.trianglehead.clockwise",
                    title: String(localized: "Step.BackgroundRefresh.Title", table: "Onboarding"),
                    description: String(localized: "Step.BackgroundRefresh.Description", table: "Onboarding")
                )

                VStack(spacing: 0) {
                    Toggle(String(localized: "BackgroundRefresh", table: "Settings"), isOn: $backgroundRefreshEnabled)
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
                .padding(.bottom, isIPad ? 20 : 0)
        }
    }
}
