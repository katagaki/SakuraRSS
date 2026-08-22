import UIKit

@MainActor
enum InstalledAppProbe {

    private static var results: [String: Bool] = [:]

    static func isInstalled(scheme: String) -> Bool {
        if let cached = results[scheme] {
            return cached
        }
        guard let url = URL(string: scheme) else {
            results[scheme] = false
            return false
        }
        let value = UIApplication.shared.canOpenURL(url)
        results[scheme] = value
        return value
    }
}
