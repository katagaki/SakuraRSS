import SwiftUI

/// One service's sign-in: its state, a button to sign in or out, and the
/// sign-in web page in a sheet.
struct AccountSessionRow<LoginView: View>: View {

    let signInTitle: String
    let signOutTitle: String
    let checkSession: () async -> Bool
    let signOut: () async -> Void
    @ViewBuilder let loginView: () -> LoginView

    @State private var isSignedIn: Bool?
    @State private var isShowingLogin = false

    var body: some View {
        Group {
            switch isSignedIn {
            case .none:
                ProgressView()
                    .controlSize(.small)
            case .some(true):
                Button(signOutTitle + "…") {
                    Task {
                        await signOut()
                        isSignedIn = await checkSession()
                    }
                }
            case .some(false):
                Button(signInTitle + "…") { isShowingLogin = true }
            }
        }
        .task { isSignedIn = await checkSession() }
        .sheet(isPresented: $isShowingLogin) {
            Task { isSignedIn = await checkSession() }
        } content: {
            loginView()
                .frame(width: 520, height: 640)
        }
    }
}
