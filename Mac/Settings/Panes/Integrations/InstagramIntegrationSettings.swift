import Hanami
import SwiftUI

struct InstagramIntegrationSettings: View {

    @AppStorage("Labs.InstagramProfileFeeds") private var profileFeedsEnabled = false
    @AppStorage("Instagram.HideReels") private var hideReels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(IntegrationText.string("InstagramProfileFeeds"), isOn: $profileFeedsEnabled)
            SettingsNote(text: IntegrationText.string("InstagramProfileFeeds.Footer"))
            if profileFeedsEnabled {
                AccountSessionRow(
                    signInTitle: IntegrationText.string("InstagramProfileFeeds.SignIn"),
                    signOutTitle: IntegrationText.string("InstagramProfileFeeds.SignOut"),
                    checkSession: { InstagramProvider.hasSession() },
                    signOut: { await InstagramProvider.clearSession() },
                    loginView: { InstagramLoginView() }
                )
            }
            Toggle(IntegrationText.string("Instagram.HideReels"), isOn: $hideReels)
                .padding(.top, 12)
            SettingsNote(text: IntegrationText.string("Instagram.HideReels.Footer"))
        }
    }
}
