import XCTest

/// What capture.sh can't do from outside the simulator: turn it, and tap into the app.
/// Values come in through `TEST_RUNNER_`-prefixed environment variables on xcodebuild.
final class DriverTests: XCTestCase {

    @MainActor
    func testLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    @MainActor
    func testPortrait() {
        XCUIDevice.shared.orientation = .portrait
    }

    /// Taps the first element in the running app that can be tapped and whose label contains
    /// `CAPTURE_TAP_LABEL`. Rows often fold their texts into one label, so it need not start with it.
    @MainActor
    func testTap() throws {
        let environment = ProcessInfo.processInfo.environment
        let bundleIdentifier = try XCTUnwrap(environment["CAPTURE_BUNDLE_ID"])
        let label = try XCTUnwrap(environment["CAPTURE_TAP_LABEL"])
        let application = XCUIApplication(bundleIdentifier: bundleIdentifier)
        application.activate()
        let matches = application.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", label))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 20), "nothing labelled \(label)")
        let element = matches.allElementsBoundByIndex.first { $0.isHittable } ?? matches.firstMatch
        element.tap()
    }
}
