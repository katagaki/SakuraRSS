import Foundation
import Security

/// CloudKit traps when used without its entitlement, which unsigned macOS
/// development builds lack.
public nonisolated enum CloudKitEntitlement {

    public static let isAvailable: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let services = SecTaskCopyValueForEntitlement(
                  task, "com.apple.developer.icloud-services" as CFString, nil
              ) as? [String] else { return false }
        return services.contains("CloudKit")
        #else
        return true
        #endif
    }()
}
