import SwiftUI

struct SubstackSettingsView: View {

    @State private var isCheckingLogin = true
    @State private var isSignedIn = false
    @State private var showLogin = false

    var body: some View {
        List {
            Section {
                if isCheckingLogin {
                    ProgressView()
                } else if isSignedIn {
                    Button(String(localized: "Substack.SignOut", table: "Integrations")) {
                        Task {
                            await SubstackAuth.clearSession()
                            isSignedIn = false
                        }
                    }
                } else {
                    Button(String(localized: "Substack.SignIn", table: "Integrations")) {
                        showLogin = true
                    }
                }
            } footer: {
                Text(String(localized: "Substack.Footer", table: "Integrations"))
            }
        }
        .navigationTitle(String(localized: "Substack", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
        .sheet(isPresented: $showLogin) {
            isCheckingLogin = true
            isSignedIn = SubstackAuth.hasSession()
            isCheckingLogin = false
        } content: {
            SubstackLoginView()
        }
        .task {
            isSignedIn = SubstackAuth.hasSession()
            isCheckingLogin = false
        }
    }
}
