import AppKit

/// A symbol button on a Feed row that runs a closure.
final class PostActionButton: NSButton {

    var handler: (NSView) -> Void = { _ in }

    init(symbolName: String, pointSize: CGFloat) {
        super.init(frame: .zero)
        isBordered = false
        imagePosition = .imageOnly
        symbolConfiguration = .init(pointSize: pointSize, weight: .semibold)
        setSymbol(symbolName)
        target = self
        action = #selector(runHandler)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setSymbol(_ symbolName: String) {
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    @objc private func runHandler() {
        handler(self)
    }
}
