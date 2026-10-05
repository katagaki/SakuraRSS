import Hanami
import SwiftUI

struct SubstackIntegrationSettings: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AccountSessionRow(
                signInTitle: IntegrationText.string("Substack.SignIn"),
                signOutTitle: IntegrationText.string("Substack.SignOut"),
                checkSession: { SubstackAuth.hasSession() },
                signOut: { await SubstackAuth.clearSession() },
                loginView: { SubstackLoginView() }
            )
            SettingsNote(text: IntegrationText.string("Substack.Footer"))
        }
    }
}
