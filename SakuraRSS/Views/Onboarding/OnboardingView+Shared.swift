import SwiftUI

extension OnboardingView {

    // MARK: - Step Header

    func stepHeader(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .padding(10)
                .frame(width: 80, height: 80)
                .foregroundStyle(.accent.gradient)
                .symbolRenderingMode(.hierarchical)
                .padding(.top, 80)
            Text(title)
                .font(.largeTitle.bold())
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Feature Row

    func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.accent)
                .symbolRenderingMode(.multicolor)
                .frame(width: 36, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Continue Button

    func continueButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(String(localized: "Continue", table: "Onboarding"))
                .fontWeight(.semibold)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
