import Foundation

/// A minimal Keychain-backed persistence layer for `HTTPCookie` arrays.
///
/// Cookies are archived with secure coding and stored as a single
/// `kSecClassGenericPassword` item per `service`.  Items are accessible
/// `kSecAttrAccessibleAfterFirstUnlock`, which means they survive
/// process relaunches and are readable from `BGAppRefreshTask`s on a
/// device that has been unlocked at least once since boot.
///
/// This exists because relying on `WKWebsiteDataStore.default()` as a
/// cookie persistence layer requires a MainActor WKWebView round-trip
/// to restore cookies from disk — unreliable from background tasks and
/// adds multi-second warming latency to cold-launch scrapes.
struct KeychainCookieStore {

    /// Keychain service identifier — unique per cookie jar.
    let service: String

    /// Single-account constant; each service stores exactly one item.
    private let account = "cookies"

    /// Persists the given cookies, replacing any previously stored value.
    func save(_ cookies: [HTTPCookie]) {
        let data: Data
        do {
            data = try NSKeyedArchiver.archivedData(
                withRootObject: cookies,
                requiringSecureCoding: true
            )
        } catch {
            #if DEBUG
            print("[KeychainCookieStore:\(service)] archive failed: \(error)")
            #endif
            return
        }

        let matchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Try update first, fall back to add on first save.
        let updateStatus = SecItemUpdate(
            matchQuery as CFDictionary,
            updateAttributes as CFDictionary
        )
        if updateStatus == errSecItemNotFound {
            var addQuery = matchQuery
            for (key, value) in updateAttributes { addQuery[key] = value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            #if DEBUG
            if addStatus != errSecSuccess {
                print("[KeychainCookieStore:\(service)] add failed: \(addStatus)")
            }
            #endif
        } else if updateStatus != errSecSuccess {
            #if DEBUG
            print("[KeychainCookieStore:\(service)] update failed: \(updateStatus)")
            #endif
        }
    }

    /// Loads the persisted cookies, or returns `nil` if no item is stored
    /// or if the archived data cannot be decoded.
    func load() -> [HTTPCookie]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        do {
            let unarchived = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, HTTPCookie.self],
                from: data
            )
            return unarchived as? [HTTPCookie]
        } catch {
            #if DEBUG
            print("[KeychainCookieStore:\(service)] unarchive failed: \(error)")
            #endif
            return nil
        }
    }

    /// Deletes the stored cookies, if any.
    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
