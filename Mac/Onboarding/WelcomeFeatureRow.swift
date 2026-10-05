import SwiftUI

struct WelcomeFeatureRow: View {

    let symbolName: String
    let key: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: String.LocalizationValue(key), table: "Onboarding"))
                    .font(.body.weight(.semibold))
                Text(String(localized: String.LocalizationValue(key + ".Description"), table: "Onboarding"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
