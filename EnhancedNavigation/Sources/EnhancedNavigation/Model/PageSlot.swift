import Foundation

/// What a page hands the chrome, tagged with the page that sent it. SwiftUI
/// re-runs `onAppear` on the page *below* the one a pop reveals, so an
/// untagged report from a background page would take the chrome over.
public struct PageSlot<Token: Hashable, Value> {
    public let token: Token?
    public let value: Value

    public init(token: Token?, value: Value) {
        self.token = token
        self.value = value
    }

    /// The value, but only for the page the chrome is currently naming.
    public func value(forPageAt token: Token?) -> Value? {
        self.token == token ? value : nil
    }

    /// A page only empties the slot it filled itself: a page below the
    /// visible one goes on reporting, and its nil would otherwise take the
    /// controls away from the page the chrome is naming.
    public static func fill(_ slot: inout PageSlot?, with value: Value?, from token: Token?) {
        if let value {
            slot = PageSlot(token: token, value: value)
        } else if slot?.token == token {
            slot = nil
        }
    }
}
