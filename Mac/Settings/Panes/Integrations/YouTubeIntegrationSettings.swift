import Hanami
import SwiftUI

struct YouTubeIntegrationSettings: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AccountSessionRow(
                signInTitle: IntegrationText.string("YouTubePlayer.SignIn"),
                signOutTitle: IntegrationText.string("YouTubePlayer.SignOut"),
                checkSession: { await YouTubeWebSession.hasSession() },
                signOut: { await YouTubeWebSession.clearSession() },
                loginView: { YouTubeLoginView() }
            )
            SettingsNote(text: IntegrationText.string("YouTubePlayer.Footer"))
        }
    }
}
