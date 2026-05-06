import Foundation

extension String {
    /// Treats `did:plc:...` / `did:web:...` handles as already-resolved actor IDs.
    var asDIDIfValid: String? {
        hasPrefix("did:") ? self : nil
    }
}
