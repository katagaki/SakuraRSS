import Foundation

/// One tab's back and forward stacks.
struct BrowserHistory {

    private(set) var backStack: [BrowserLocation] = []
    private(set) var current: BrowserLocation
    private(set) var forwardStack: [BrowserLocation] = []

    init(current: BrowserLocation) {
        self.current = current
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    mutating func navigate(to location: BrowserLocation) {
        guard location != current else { return }
        backStack.append(current)
        current = location
        forwardStack.removeAll()
    }

    mutating func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(current)
        current = previous
    }

    mutating func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(current)
        current = next
    }
}
