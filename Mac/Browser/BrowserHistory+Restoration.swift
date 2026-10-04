import AppKit

extension BrowserHistory {

    private enum Key {
        static let back = "BrowserHistory.Back"
        static let current = "BrowserHistory.Current"
        static let forward = "BrowserHistory.Forward"
    }

    func encode(with coder: NSCoder) {
        coder.encode(backStack.map(\.persistenceToken) as NSArray, forKey: Key.back)
        coder.encode(current.persistenceToken as NSString, forKey: Key.current)
        coder.encode(forwardStack.map(\.persistenceToken) as NSArray, forKey: Key.forward)
    }

    init?(coder: NSCoder) {
        guard let currentToken = coder.decodeObject(of: NSString.self, forKey: Key.current) as String?,
              let current = BrowserLocation(persistenceToken: currentToken) else { return nil }
        self.init(
            backStack: Self.decodeLocations(from: coder, forKey: Key.back),
            current: current,
            forwardStack: Self.decodeLocations(from: coder, forKey: Key.forward)
        )
    }

    private static func decodeLocations(from coder: NSCoder, forKey key: String) -> [BrowserLocation] {
        let tokens = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: key) ?? []
        return tokens.compactMap { BrowserLocation(persistenceToken: $0 as String) }
    }
}
