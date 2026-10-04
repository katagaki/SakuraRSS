import Foundation
import Security

/// Reads the app's own signed entitlements. CloudKit raises an exception when
/// used without its entitlement, which unsigned development builds lack.
enum AppEntitlements {

    static var hasCloudKit: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let services = SecTaskCopyValueForEntitlement(
                  task, "com.apple.developer.icloud-services" as CFString, nil
              ) as? [String] else { return false }
        return services.contains("CloudKit")
    }
}
