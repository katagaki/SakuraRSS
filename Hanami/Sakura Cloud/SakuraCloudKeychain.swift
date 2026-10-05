import Foundation

nonisolated enum SakuraCloudKeychain {

    static let service = "com.tsubuzaki.SakuraRSS.SakuraCloud"
    static let keyIDAccount = "AppAttestKeyID"

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = KeychainAccess.perform(query) { query in
            SecItemCopyMatching(query as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String?, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        _ = KeychainAccess.perform(query) { query in
            SecItemDelete(query as CFDictionary)
        }
        guard let value, !value.isEmpty else { return }
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        _ = KeychainAccess.perform(item) { query in
            SecItemAdd(query as CFDictionary, nil)
        }
    }
}
