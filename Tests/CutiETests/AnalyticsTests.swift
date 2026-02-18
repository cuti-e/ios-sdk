import XCTest
@testable import CutiE

final class AnalyticsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CutiEAnalytics.shared.resetForTesting()
    }

    override func tearDown() {
        CutiEAnalytics.shared.resetForTesting()
        super.tearDown()
    }

    // MARK: - Default State

    func testDefaultStateIsDisabled() {
        XCTAssertFalse(CutiEAnalytics.shared.isEnabled)
    }

    func testDefaultConsentNotAsked() {
        XCTAssertFalse(CutiEAnalytics.shared.hasBeenAsked)
    }

    // MARK: - Consent Persistence

    func testEnableAnalyticsPersists() {
        CutiEAnalytics.shared.isEnabled = true
        XCTAssertTrue(CutiEAnalytics.shared.isEnabled)
        XCTAssertTrue(CutiEAnalytics.shared.hasBeenAsked)
    }

    func testDisableAnalyticsPersists() {
        CutiEAnalytics.shared.isEnabled = true
        CutiEAnalytics.shared.isEnabled = false
        XCTAssertFalse(CutiEAnalytics.shared.isEnabled)
        XCTAssertTrue(CutiEAnalytics.shared.hasBeenAsked, "hasBeenAsked should stay true after withdrawal")
    }

    func testConsentWithdrawal() {
        // Grant
        CutiEAnalytics.shared.isEnabled = true
        XCTAssertTrue(CutiEAnalytics.shared.isEnabled)

        // Withdraw
        CutiEAnalytics.shared.isEnabled = false
        XCTAssertFalse(CutiEAnalytics.shared.isEnabled)
        XCTAssertTrue(CutiEAnalytics.shared.hasBeenAsked)
    }

    // MARK: - Hashed Device ID

    func testHashedDeviceIDIs64CharHex() {
        // Configure SDK so deviceID is stable
        CutiE.shared.configure(appId: "app_test", apiURL: "https://test.api.com")

        let hashedID = CutiEAnalytics.shared.generateHashedDeviceID()
        XCTAssertEqual(hashedID.count, 64, "SHA256 hex digest must be 64 characters")

        let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(
            hashedID.unicodeScalars.allSatisfy { hexChars.contains($0) },
            "Hashed ID must contain only hex characters"
        )
    }

    func testHashedDeviceIDIsConsistent() {
        // Configure SDK so deviceID is stable
        CutiE.shared.configure(appId: "app_test", apiURL: "https://test.api.com")

        let id1 = CutiEAnalytics.shared.generateHashedDeviceID()
        let id2 = CutiEAnalytics.shared.generateHashedDeviceID()
        XCTAssertEqual(id1, id2, "Hashed device ID must be deterministic")
    }

    // MARK: - Public API Delegation

    func testPublicAPIDelegatesToAnalytics() {
        let cutiE = CutiE.shared

        XCTAssertFalse(cutiE.analyticsEnabled)
        XCTAssertFalse(cutiE.hasAskedForAnalyticsConsent)

        cutiE.setAnalyticsConsent(true)
        XCTAssertTrue(cutiE.analyticsEnabled)
        XCTAssertTrue(cutiE.hasAskedForAnalyticsConsent)

        cutiE.setAnalyticsConsent(false)
        XCTAssertFalse(cutiE.analyticsEnabled)
    }

    // MARK: - Safety Without Configuration

    func testNoCrashWithoutConfiguration() {
        // Ensure SDK is not configured
        let savedConfig = CutiE.shared.configuration
        let savedClient = CutiE.shared.apiClient
        CutiE.shared.configuration = nil
        CutiE.shared.apiClient = nil

        // Enable analytics and trigger ping — should not crash
        CutiEAnalytics.shared.isEnabled = true
        CutiEAnalytics.shared.sendActivityPingIfNeeded()

        // Restore
        CutiE.shared.configuration = savedConfig
        CutiE.shared.apiClient = savedClient
    }

    func testNoPingWithoutConsent() {
        // Configure SDK
        CutiE.shared.configure(appId: "app_test", apiURL: "https://test.api.com")

        // Without consent, sendActivityPingIfNeeded should be a no-op
        // (we can't easily verify no network call, but at least no crash)
        CutiEAnalytics.shared.sendActivityPingIfNeeded()
        XCTAssertFalse(CutiEAnalytics.shared.isEnabled)
    }
}
