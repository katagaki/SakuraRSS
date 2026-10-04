import Foundation

/// Mac Catalyst keeps items in the data protection keychain while native macOS
/// defaults to the legacy file keychain, so the AppKit app opts in to find what
/// the Catalyst build stored. Unprovisioned builds lack the entitlement for it,
/// and only writes report that, so it is probed once with a delete.
nonisolated enum KeychainAccess {

    #if os(macOS)
    private static let usesDataProtectionKeychain: Bool = {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tsubuzaki.SakuraRSS.KeychainProbe",
            kSecUseDataProtectionKeychain as String: true
        ]
        return SecItemDelete(probe as CFDictionary) != errSecMissingEntitlement
    }()
    #endif

    static func perform(_ query: [String: Any], _ operation: ([String: Any]) -> OSStatus) -> OSStatus {
        #if os(macOS)
        if usesDataProtectionKeychain {
            var dataProtectionQuery = query
            dataProtectionQuery[kSecUseDataProtectionKeychain as String] = true
            return operation(dataProtectionQuery)
        }
        #endif
        return operation(query)
    }
}
