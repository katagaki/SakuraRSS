import Foundation

/// Keychain-backed persistence for `HTTPCookie` arrays, readable from background tasks.
struct KeychainCookieStore {

    let service: String
    private let account = "cookies"

    /// Persists cookies, replacing any previously stored value.
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

    /// Loads persisted cookies, or `nil` if none stored or decode fails.
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

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
