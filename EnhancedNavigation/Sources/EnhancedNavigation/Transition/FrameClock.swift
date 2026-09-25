import QuartzCore

/// Waits on the display, so work queued now has been laid out and drawn
/// before whatever comes next starts.
public enum FrameClock {

    /// Two frames rather than one: a tab mounted by the selection runs its
    /// `onAppear` and first state changes in the frame after its own.
    public static func waitForSettledFrames() async {
        await nextFrame()
        await nextFrame()
    }

    private static func nextFrame() async {
        await withCheckedContinuation { continuation in
            FrameWaiter(continuation: continuation).start()
        }
    }
}

private final class FrameWaiter: NSObject {

    private var continuation: CheckedContinuation<Void, Never>?
    private var displayLink: CADisplayLink?

    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    /// The display link holds its target, which keeps this alive until the
    /// first tick invalidates it.
    func start() {
        let displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    @objc private func tick() {
        displayLink?.invalidate()
        displayLink = nil
        continuation?.resume()
        continuation = nil
    }
}
