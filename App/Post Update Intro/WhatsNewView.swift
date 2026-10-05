import SwiftUI
import Hanami

struct WhatsNewView: View {

    var onDismiss: () -> Void

    private var isiPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(.sakuraIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 80)
                    Text(String(localized: "WhatsNew.Title", table: "Onboarding"))
                        .font(.largeTitle.bold())
                }

                VStack(alignment: .leading, spacing: 24) {
                    WhatsNewFeatureRow(symbolName: "square.on.square", key: "WhatsNew.Tabs")
                    WhatsNewFeatureRow(symbolName: "magnifyingglass", key: "WhatsNew.AddressBar")
                    WhatsNewFeatureRow(symbolName: "square.grid.2x2.fill", key: "WhatsNew.StartPage")
                    WhatsNewFeatureRow(symbolName: "bookmark.fill", key: "WhatsNew.Bookmarks")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                onDismiss()
            } label: {
                Text(String(localized: "Continue", table: "Onboarding"))
                    .fontWeight(.semibold)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
            .compatibleGlassProminentButtonStyle()
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .padding(.bottom, isiPad ? 20 : 8)
        }
    }
}
