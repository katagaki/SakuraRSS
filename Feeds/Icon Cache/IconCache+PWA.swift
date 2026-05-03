import UIKit

extension IconCache {

    /// Fetches a high-quality icon from a web app manifest or apple-touch-icon.
    nonisolated func fetchPWAIcon(from siteURL: URL) async -> UIImage? {
        do {
            let (data, _) = try await Self.urlSession.data(from: siteURL)
            guard let html = String(data: data, encoding: .utf8) else {
                log("Icon", "PWA: failed to decode HTML from \(siteURL)")
                return nil
            }

            if let manifestHref = extractLinkHref(from: html, rel: "manifest"),
               let manifestURL = URL(string: manifestHref, relativeTo: siteURL),
               let icon = await fetchManifestIcon(from: manifestURL.absoluteURL) {
                log("Icon", "PWA: found manifest icon from \(manifestURL.absoluteURL)")
                return icon
            }

            if let touchIconHref = extractLinkHref(from: html, rel: "apple-touch-icon"),
               let iconURL = URL(string: touchIconHref, relativeTo: siteURL) {
                let (iconData, _) = try await Self.urlSession.data(from: iconURL.absoluteURL)
                if let image = UIImage(data: iconData), image.size.width >= 48 {
                    // swiftlint:disable:next line_length
                    log("Icon", "PWA: found apple-touch-icon from \(iconURL.absoluteURL) (\(image.size.width)x\(image.size.height))")
                    return image
                }
                log("Icon", "PWA: apple-touch-icon too small or invalid from \(iconURL.absoluteURL)")
            }

            log("Icon", "PWA: no suitable icon found for \(siteURL)")
            return nil
        } catch {
            log("Icon", "PWA: fetch failed for \(siteURL): \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches the largest icon from a web app manifest JSON.
    nonisolated func fetchManifestIcon(from manifestURL: URL) async -> UIImage? {
        do {
            let (data, _) = try await Self.urlSession.data(from: manifestURL)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let icons = json["icons"] as? [[String: Any]] else { return nil }

            var bestIcon: (url: String, size: Int)?
            for icon in icons {
                guard let src = icon["src"] as? String else { continue }
                let size = parseIconSize(icon["sizes"] as? String)
                if size > (bestIcon?.size ?? 0) {
                    bestIcon = (src, size)
                }
            }

            guard let iconSrc = bestIcon?.url,
                  let iconURL = URL(string: iconSrc, relativeTo: manifestURL) else { return nil }

            let (iconData, _) = try await Self.urlSession.data(from: iconURL.absoluteURL)
            if let image = UIImage(data: iconData), image.size.width >= 64 {
                return image
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Fetches the apple-touch-icon referenced by the homepage's `<link rel="apple-touch-icon">` tag.
    nonisolated func fetchAppleTouchIcon(from siteURL: URL) async -> UIImage? {
        do {
            let (data, _) = try await Self.urlSession.data(from: siteURL)
            guard let html = String(data: data, encoding: .utf8),
                  let touchIconHref = extractLinkHref(from: html, rel: "apple-touch-icon"),
                  let iconURL = URL(string: touchIconHref, relativeTo: siteURL) else {
                return nil
            }
            let (iconData, _) = try await Self.urlSession.data(from: iconURL.absoluteURL)
            return UIImage(data: iconData)
        } catch {
            return nil
        }
    }

    /// Parses icon size strings like "192x192" and returns the width.
    nonisolated func parseIconSize(_ sizes: String?) -> Int {
        guard let sizes = sizes else { return 0 }
        let parts = sizes.lowercased().split(separator: "x")
        return Int(parts.first ?? "") ?? 0
    }
}
