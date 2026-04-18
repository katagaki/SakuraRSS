import UIKit

extension FaviconCache {

    /// Fetches a high-quality icon from a web app manifest or apple-touch-icon.
    nonisolated func fetchPWAIcon(from siteURL: URL) async -> UIImage? {
        do {
            let (data, _) = try await Self.urlSession.data(from: siteURL)
            guard let html = String(data: data, encoding: .utf8) else {
                #if DEBUG
                debugPrint("[Favicon] PWA: failed to decode HTML from \(siteURL)")
                #endif
                return nil
            }

            // 1. Try web app manifest
            if let manifestHref = extractLinkHref(from: html, rel: "manifest"),
               let manifestURL = URL(string: manifestHref, relativeTo: siteURL),
               let icon = await fetchManifestIcon(from: manifestURL.absoluteURL) {
                #if DEBUG
                debugPrint("[Favicon] PWA: found manifest icon from \(manifestURL.absoluteURL)")
                #endif
                return icon
            }

            // 2. Try apple-touch-icon (typically 180x180)
            if let touchIconHref = extractLinkHref(from: html, rel: "apple-touch-icon"),
               let iconURL = URL(string: touchIconHref, relativeTo: siteURL) {
                let (iconData, _) = try await Self.urlSession.data(from: iconURL.absoluteURL)
                if let image = UIImage(data: iconData), image.size.width >= 64 {
                    #if DEBUG
                    debugPrint("[Favicon] PWA: found apple-touch-icon from \(iconURL.absoluteURL) (\(image.size.width)x\(image.size.height))")
                    #endif
                    return image
                }
                #if DEBUG
                debugPrint("[Favicon] PWA: apple-touch-icon too small or invalid from \(iconURL.absoluteURL)")
                #endif
            }

            #if DEBUG
            debugPrint("[Favicon] PWA: no suitable icon found for \(siteURL)")
            #endif
            return nil
        } catch {
            #if DEBUG
            debugPrint("[Favicon] PWA: fetch failed for \(siteURL): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetches the largest icon from a web app manifest JSON.
    nonisolated func fetchManifestIcon(from manifestURL: URL) async -> UIImage? {
        do {
            let (data, _) = try await Self.urlSession.data(from: manifestURL)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let icons = json["icons"] as? [[String: Any]] else { return nil }

            // Find the largest square icon
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

    /// Parses icon size strings like "192x192" and returns the width.
    nonisolated func parseIconSize(_ sizes: String?) -> Int {
        guard let sizes = sizes else { return 0 }
        let parts = sizes.lowercased().split(separator: "x")
        return Int(parts.first ?? "") ?? 0
    }
}
