import Hanami
import SwiftUI

struct XIntegrationSettings: View {

    @AppStorage("Labs.XProfileFeeds") private var profileFeedsEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(IntegrationText.string("XProfileFeeds"), isOn: $profileFeedsEnabled)
            SettingsNote(text: IntegrationText.string("XProfileFeeds.Footer"))
            if profileFeedsEnabled {
                AccountSessionRow(
                    signInTitle: IntegrationText.string("XProfileFeeds.SignIn"),
                    signOutTitle: IntegrationText.string("XProfileFeeds.SignOut"),
                    checkSession: { XProvider.hasSession() },
                    signOut: { await XProvider.clearSession() },
                    loginView: { XLoginView() }
                )
            }
        }
    }
}
