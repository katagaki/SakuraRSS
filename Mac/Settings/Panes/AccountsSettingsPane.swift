import Hanami
import SwiftUI

struct AccountsSettingsPane: View {

    @AppStorage("Labs.InstagramProfileFeeds") private var instagramProfileFeedsEnabled = false
    @AppStorage("Instagram.HideReels") private var hideReels = false
    @AppStorage("Labs.XProfileFeeds") private var xProfileFeedsEnabled = false
    @AppStorage("Labs.PetalRecipes") private var webFeedsEnabled = false
    @Environment(FeedManager.self) private var feedManager
    @State private var isManagingWebFeeds = false

    var body: some View {
        SettingsForm {
            LabeledContent(text("Petal")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(text("Petal"), isOn: $webFeedsEnabled)
                    Button(String(localized: "Manage.Title", table: "Petal") + "…") { isManagingWebFeeds = true }
                        .disabled(!webFeedsEnabled)
                    SettingsNote(text: text("Petal.Footer"))
                }
            }
            SettingsGroupSpacer()
            LabeledContent(text("Instagram")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(text("InstagramProfileFeeds"), isOn: $instagramProfileFeedsEnabled)
                    if instagramProfileFeedsEnabled {
                        AccountSessionRow(
                            signInTitle: text("InstagramProfileFeeds.SignIn"),
                            signOutTitle: text("InstagramProfileFeeds.SignOut"),
                            checkSession: { InstagramProvider.hasSession() },
                            signOut: { await InstagramProvider.clearSession() },
                            loginView: { InstagramLoginView() }
                        )
                    }
                    SettingsNote(text: text("InstagramProfileFeeds.Footer"))
                    Toggle(text("Instagram.HideReels"), isOn: $hideReels)
                        .padding(.top, 4)
                    SettingsNote(text: text("Instagram.HideReels.Footer"))
                }
            }
            SettingsGroupSpacer()
            LabeledContent(text("Substack")) {
                VStack(alignment: .leading, spacing: 6) {
                    AccountSessionRow(
                        signInTitle: text("Substack.SignIn"),
                        signOutTitle: text("Substack.SignOut"),
                        checkSession: { SubstackAuth.hasSession() },
                        signOut: { await SubstackAuth.clearSession() },
                        loginView: { SubstackLoginView() }
                    )
                    SettingsNote(text: text("Substack.Footer"))
                }
            }
            SettingsGroupSpacer()
            LabeledContent(text("X")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(text("XProfileFeeds"), isOn: $xProfileFeedsEnabled)
                    if xProfileFeedsEnabled {
                        AccountSessionRow(
                            signInTitle: text("XProfileFeeds.SignIn"),
                            signOutTitle: text("XProfileFeeds.SignOut"),
                            checkSession: { XProvider.hasSession() },
                            signOut: { await XProvider.clearSession() },
                            loginView: { XLoginView() }
                        )
                    }
                    SettingsNote(text: text("XProfileFeeds.Footer"))
                }
            }
            SettingsGroupSpacer()
            LabeledContent(text("YouTube")) {
                VStack(alignment: .leading, spacing: 6) {
                    AccountSessionRow(
                        signInTitle: text("YouTubePlayer.SignIn"),
                        signOutTitle: text("YouTubePlayer.SignOut"),
                        checkSession: { await YouTubeWebSession.hasSession() },
                        signOut: { await YouTubeWebSession.clearSession() },
                        loginView: { YouTubeLoginView() }
                    )
                    SettingsNote(text: text("YouTubePlayer.Footer"))
                }
            }
        }
        .sheet(isPresented: $isManagingWebFeeds) { manageWebFeedsSheet }
    }

    private var manageWebFeedsSheet: some View {
        NavigationStack {
            PetalSettingsView()
                .formStyle(.grouped)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Shared.Done")) { isManagingWebFeeds = false }
                    }
                }
        }
        .environment(feedManager)
        .frame(width: 560, height: 560)
    }

    private func text(_ key: String.LocalizationValue) -> String {
        String(localized: key, table: "Integrations")
    }
}
