import SwiftUI

/// The app's About window, laid out like Chrome's used to be: who it is and
/// which version, then the open source software it's built with.
struct AboutView: View {

    private var version: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return String(localized: "About.Version \(shortVersion) \(build)", table: "Mac")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                VStack(alignment: .leading, spacing: 4) {
                    Text(MainMenuBuilder.applicationName)
                        .font(.title.bold())
                    Text(version)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Link(destination: URL(string: "https://github.com/katagaki/SakuraRSS")!) {
                        Text("More.SourceCode")
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            Divider()
            AboutAttributionsList()
        }
        .frame(width: 560, height: 520)
    }
}
