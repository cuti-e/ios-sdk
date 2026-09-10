import XCTest
@testable import CutiE

final class AnalyticsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CutiEAnalytics.shared.resetForTesting()
        // Every test in this file runs against a fake transport: no test touches the network.
        CutiEAnalytics.shared.pingTransportOverride = { _, completion in
            completion(.delivered(statusCode: 204))
        }
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

    // MARK: - Daily Ping Cadence (once per UTC day, not once per launch)

    /// Fake transport: records every hashed ID it is asked to send, hits no network.
    private final class PingRecorder {
        private(set) var sentHashes: [String] = []
        var outcome: CutiEActivityPingOutcome = .delivered(statusCode: 204)

        var transport: (String, @escaping (CutiEActivityPingOutcome) -> Void) -> Void {
            return { [weak self] hashedID, completion in
                self?.sentHashes.append(hashedID)
                completion(self?.outcome ?? .delivered(statusCode: 204))
            }
        }

        var count: Int { sentHashes.count }
    }

    private func day(_ iso: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let date = formatter.date(from: iso) else {
            XCTFail("Bad fixture date \(iso)")
            return Date()
        }
        return date
    }

    /// Arrange a consented, configured SDK with a fake clock and fake transport.
    private func makeConsentedAnalytics(at date: Date) -> (CutiEAnalytics, PingRecorder) {
        CutiE.shared.configure(appId: "app_test", apiURL: "https://test.api.com")
        let analytics = CutiEAnalytics.shared
        let recorder = PingRecorder()
        analytics.dateProvider = { date }
        analytics.pingTransportOverride = recorder.transport
        return (analytics, recorder)
    }

    func testFirstLaunchWithConsentSendsPing() {
        let now = day("2026-03-01 09:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)

        analytics.isEnabled = true // consent granted -> pings immediately

        XCTAssertEqual(recorder.count, 1, "A consented first launch must ping")
        XCTAssertEqual(analytics.lastPingDay, "2026-03-01")
    }

    func testSecondLaunchSameDayDoesNotPing() {
        let now = day("2026-03-01 09:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)

        analytics.isEnabled = true
        XCTAssertEqual(recorder.count, 1)

        // Simulate a fresh process launch on the same UTC day: consent is already persisted,
        // configure() runs again, onSDKConfigured() fires.
        analytics.onSDKConfigured()
        analytics.sendActivityPingIfNeeded()

        XCTAssertEqual(recorder.count, 1, "Same UTC day must not ping twice")
    }

    func testNextDayLaunchSendsPing() {
        var now = day("2026-03-01 22:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        analytics.dateProvider = { now }

        analytics.isEnabled = true
        XCTAssertEqual(recorder.count, 1)

        // Next UTC day, new launch
        now = day("2026-03-02 08:00")
        analytics.onSDKConfigured()

        XCTAssertEqual(recorder.count, 2, "A new UTC day must ping again")
        XCTAssertEqual(analytics.lastPingDay, "2026-03-02")
    }

    func testForegroundAfterMidnightUTCSendsPing() {
        var now = day("2026-03-01 23:50")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        analytics.dateProvider = { now }

        analytics.isEnabled = true
        XCTAssertEqual(recorder.count, 1)

        // App is backgrounded, never force-quit, and resumed 20 minutes later — next UTC day.
        now = day("2026-03-02 00:10")
        analytics.appDidBecomeActive()

        XCTAssertEqual(recorder.count, 2, "Returning to foreground after midnight UTC must ping")
        XCTAssertEqual(analytics.lastPingDay, "2026-03-02")
    }

    func testForegroundSameDayDoesNotPing() {
        var now = day("2026-03-01 10:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        analytics.dateProvider = { now }

        analytics.isEnabled = true
        now = day("2026-03-01 18:00")
        analytics.appDidBecomeActive()
        analytics.appDidBecomeActive()

        XCTAssertEqual(recorder.count, 1, "At most one ping per device per UTC day")
    }

    func testConsentOffNeverPings() {
        var now = day("2026-03-01 10:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        analytics.dateProvider = { now }

        XCTAssertFalse(analytics.isEnabled)
        analytics.sendActivityPingIfNeeded()
        analytics.onSDKConfigured()
        analytics.appDidBecomeActive()

        now = day("2026-03-05 10:00")
        analytics.sendActivityPingIfNeeded()
        analytics.appDidBecomeActive()

        XCTAssertEqual(recorder.count, 0, "No consent means no ping, ever")
        XCTAssertNil(analytics.lastPingDay)
    }

    func testConsentWithdrawalStopsFuturePings() {
        var now = day("2026-03-01 10:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        analytics.dateProvider = { now }

        analytics.isEnabled = true
        XCTAssertEqual(recorder.count, 1)

        analytics.isEnabled = false
        now = day("2026-03-02 10:00")
        analytics.appDidBecomeActive()
        analytics.sendActivityPingIfNeeded()

        XCTAssertEqual(recorder.count, 1, "Withdrawn consent must stop the daily ping")
    }

    func testForegroundObserverIsRegisteredWhenConsentGranted() {
        let now = day("2026-03-01 10:00")
        let (analytics, _) = makeConsentedAnalytics(at: now)

        XCTAssertFalse(analytics.isObserving)
        analytics.isEnabled = true
        XCTAssertTrue(analytics.isObserving, "Foreground observer must be live while consent is on")

        analytics.isEnabled = false
        XCTAssertFalse(analytics.isObserving)
    }

    func testUTCDayStringUsesUTCNotLocalTime() {
        // 23:30 UTC on 1 March is already 2 March in, e.g., CET+2 — the day must stay UTC.
        let date = day("2026-03-01 23:30")
        XCTAssertEqual(CutiEAnalytics.utcDayString(from: date), "2026-03-01")
    }

    // MARK: - Ping Outcome Recording

    func testDeliveredPingIsCountedAsDelivered() {
        let now = day("2026-03-01 10:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        recorder.outcome = .delivered(statusCode: 204)

        analytics.isEnabled = true

        let diagnostics = analytics.diagnostics
        XCTAssertEqual(diagnostics.deliveredCount, 1)
        XCTAssertEqual(diagnostics.rejectedCount, 0)
        XCTAssertEqual(diagnostics.lastStatusCode, 204)
        XCTAssertNil(diagnostics.lastFailureReason)
    }

    func testRejectedPingIsRecordedNotSwallowed() {
        let now = day("2026-03-01 10:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        recorder.outcome = .rejected(statusCode: 401)

        analytics.isEnabled = true

        let diagnostics = analytics.diagnostics
        XCTAssertEqual(diagnostics.rejectedCount, 1)
        XCTAssertEqual(diagnostics.deliveredCount, 0)
        XCTAssertEqual(diagnostics.lastStatusCode, 401)
        XCTAssertEqual(diagnostics.lastFailureReason, "http_401")
        XCTAssertNotNil(diagnostics.lastAttemptDate)
    }

    func testTransportFailureIsRecorded() {
        let now = day("2026-03-01 10:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        recorder.outcome = .transportFailure(reason: "urlerror_-1009")

        analytics.isEnabled = true

        let diagnostics = analytics.diagnostics
        XCTAssertEqual(diagnostics.transportFailureCount, 1)
        XCTAssertNil(diagnostics.lastStatusCode)
        XCTAssertEqual(diagnostics.lastFailureReason, "urlerror_-1009")
    }

    func testDiagnosticsNeverContainTheHashedDeviceID() {
        let now = day("2026-03-01 10:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        recorder.outcome = .rejected(statusCode: 403)

        analytics.isEnabled = true

        let hashedID = analytics.generateHashedDeviceID()
        let diagnostics = analytics.diagnostics
        XCTAssertFalse(hashedID.isEmpty)
        XCTAssertNotEqual(diagnostics.lastFailureReason, hashedID)
        XCTAssertFalse(diagnostics.lastFailureReason?.contains(hashedID) ?? false)
    }

    func testDiagnosticsAreExposedOnPublicAPI() {
        let now = day("2026-03-01 10:00")
        let (analytics, recorder) = makeConsentedAnalytics(at: now)
        recorder.outcome = .rejected(statusCode: 500)

        analytics.isEnabled = true

        XCTAssertEqual(CutiE.shared.activityPingDiagnostics.rejectedCount, 1)
        XCTAssertEqual(CutiE.shared.activityPingDiagnostics.lastStatusCode, 500)
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
