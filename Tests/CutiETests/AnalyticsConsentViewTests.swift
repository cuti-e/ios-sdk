import XCTest
import SwiftUI
@testable import CutiE

#if os(iOS)
@available(iOS 16.0, *)
final class AnalyticsConsentViewTests: XCTestCase {

    // MARK: - View Construction

    func testViewCreatesWithAppName() {
        let view = CutiEAnalyticsConsentView(appName: "Test App") { _ in }
        XCTAssertEqual(view.appName, "Test App")
    }

    // MARK: - Callback Behavior

    func testAllowCallbackReturnsTrue() {
        let expectation = expectation(description: "Allow callback")
        var result: Bool?

        let view = CutiEAnalyticsConsentView(appName: "Test") { granted in
            result = granted
            expectation.fulfill()
        }

        view.onDecision(true)
        waitForExpectations(timeout: 1)
        XCTAssertTrue(result == true)
    }

    func testDeclineCallbackReturnsFalse() {
        let expectation = expectation(description: "Decline callback")
        var result: Bool?

        let view = CutiEAnalyticsConsentView(appName: "Test") { granted in
            result = granted
            expectation.fulfill()
        }

        view.onDecision(false)
        waitForExpectations(timeout: 1)
        XCTAssertFalse(result ?? true)
    }

    // MARK: - Content Rendering

    func testDescriptionTextIsComplete() {
        let expectedDescription = "Allow anonymous usage data to help us understand how the app is used. No personal information is collected"

        let hostingController = UIHostingController(
            rootView: CutiEAnalyticsConsentView(appName: "Fast-E") { _ in }
        )
        hostingController.loadViewIfNeeded()

        // Render at iPhone SE width to catch truncation on small screens
        let smallScreenSize = CGSize(width: 320, height: 480)
        hostingController.view.frame = CGRect(origin: .zero, size: smallScreenSize)
        hostingController.view.layoutIfNeeded()

        let descriptionFound = findLabel(containing: expectedDescription, in: hostingController.view)
        XCTAssertTrue(descriptionFound, "Full description text must be visible without truncation")
    }

    func testTitleContainsAppName() {
        let hostingController = UIHostingController(
            rootView: CutiEAnalyticsConsentView(appName: "My App") { _ in }
        )
        hostingController.loadViewIfNeeded()
        hostingController.view.frame = CGRect(origin: .zero, size: CGSize(width: 375, height: 667))
        hostingController.view.layoutIfNeeded()

        let titleFound = findLabel(containing: "Help Improve My App", in: hostingController.view)
        XCTAssertTrue(titleFound, "Title should contain the app name")
    }

    func testViewHasAllowAndDeclineButtons() {
        let hostingController = UIHostingController(
            rootView: CutiEAnalyticsConsentView(appName: "Test") { _ in }
        )
        hostingController.loadViewIfNeeded()
        hostingController.view.frame = CGRect(origin: .zero, size: CGSize(width: 375, height: 667))
        hostingController.view.layoutIfNeeded()

        let allowFound = findLabel(containing: "Allow", in: hostingController.view)
        let notNowFound = findLabel(containing: "Not Now", in: hostingController.view)

        XCTAssertTrue(allowFound, "Allow button must be present")
        XCTAssertTrue(notNowFound, "Not Now button must be present")
    }

    // MARK: - Helpers

    private func findLabel(containing text: String, in view: UIView) -> Bool {
        if let label = view as? UILabel, let labelText = label.text, labelText.contains(text) {
            return true
        }
        if let accessibilityLabel = view.accessibilityLabel, accessibilityLabel.contains(text) {
            return true
        }
        for subview in view.subviews {
            if findLabel(containing: text, in: subview) {
                return true
            }
        }
        return false
    }
}
#endif
