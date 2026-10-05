import Foundation
import SwiftSoup

extension InstagramProvider {
    static func parseProfileHTML(_ html: String, username: String) -> InstagramProfileBootstrap? {
        guard let document = try? SwiftSoup.parse(html),
              let scripts = try? document.select("script[type=application/json]") else { return nil }
        var dtsgToken: String?
        var lsdToken: String?
        for script in scripts.array() {
            guard let body = try? script.html(),
                  let data = body.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) else { continue }
            dtsgToken = dtsgToken ?? bootstrapToken(named: "DTSGInitialData", in: payload)
            lsdToken = lsdToken ?? bootstrapToken(named: "LSD", in: payload)
            if dtsgToken != nil, lsdToken != nil { break }
        }
        guard let dtsgToken, !dtsgToken.isEmpty, let lsdToken, !lsdToken.isEmpty,
              let metadata = parseProfileMetadata(document, username: username) else { return nil }
        return InstagramProfileBootstrap(
            dtsgToken: dtsgToken,
            lsdToken: lsdToken,
            displayName: metadata.displayName,
            profileImageURL: metadata.profileImageURL
        )
    }

    static func parseProfileMetadata(_ html: String, username: String) -> InstagramProfileMetadata? {
        guard let document = try? SwiftSoup.parse(html) else { return nil }
        return parseProfileMetadata(document, username: username)
    }

    private static func parseProfileMetadata(_ document: Document, username: String) -> InstagramProfileMetadata? {
        guard let title = try? document.select("meta[property=og:title]").first()?.attr("content"),
              let displayName = profileDisplayName(title: title, username: username) else { return nil }
        let profileImageURL = (try? document.select("meta[property=og:image]").first()?.attr("content"))
            .flatMap { $0.isEmpty ? nil : $0 }
        return InstagramProfileMetadata(
            displayName: displayName.isEmpty ? nil : displayName,
            profileImageURL: profileImageURL
        )
    }

    private static func profileDisplayName(title: String, username: String) -> String? {
        guard let handleRange = title.range(of: "(@\(username))", options: .caseInsensitive) else { return nil }
        return String(title[..<handleRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bootstrapToken(named name: String, in payload: Any, depth: Int = 0) -> String? {
        guard depth < 40 else { return nil }
        if let values = payload as? [Any] {
            if values.count > 2, values[0] as? String == name,
               let properties = values[2] as? [String: Any],
               let token = properties["token"] as? String, !token.isEmpty {
                return token
            }
            for value in values {
                if let token = bootstrapToken(named: name, in: value, depth: depth + 1) { return token }
            }
        } else if let properties = payload as? [String: Any] {
            for value in properties.values {
                if let token = bootstrapToken(named: name, in: value, depth: depth + 1) { return token }
            }
        }
        return nil
    }
}
