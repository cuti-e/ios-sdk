import XCTest
@testable import CutiE

final class CertificatePinningTests: XCTestCase {

    // MARK: - Domain Pinning Tests

    func testRequiresPinningForProductionDomain() {
        let pinning = CutiECertificatePinning.shared
        XCTAssertTrue(pinning.requiresPinning(for: "api.cuti-e.com"))
    }

    func testRequiresPinningForSandboxDomain() {
        let pinning = CutiECertificatePinning.shared
        XCTAssertTrue(pinning.requiresPinning(for: "cutie-worker-sandbox.invotekas.workers.dev"))
    }

    func testRequiresPinningForWorkersDomain() {
        let pinning = CutiECertificatePinning.shared
        XCTAssertTrue(pinning.requiresPinning(for: "invotekas.workers.dev"))
    }

    func testRequiresPinningForSubdomain() {
        let pinning = CutiECertificatePinning.shared
        // Subdomain of a pinned domain should also require pinning
        XCTAssertTrue(pinning.requiresPinning(for: "sub.api.cuti-e.com"))
    }

    func testDoesNotRequirePinningForUnrelatedDomain() {
        let pinning = CutiECertificatePinning.shared
        XCTAssertFalse(pinning.requiresPinning(for: "google.com"))
    }

    func testDoesNotRequirePinningForAppleDomain() {
        let pinning = CutiECertificatePinning.shared
        XCTAssertFalse(pinning.requiresPinning(for: "api.apple.com"))
    }

    func testDoesNotRequirePinningForEmptyString() {
        let pinning = CutiECertificatePinning.shared
        XCTAssertFalse(pinning.requiresPinning(for: ""))
    }

    func testDoesNotRequirePinningForPartialMatch() {
        let pinning = CutiECertificatePinning.shared
        // "cuti-e.com" alone is NOT in the pinned list (only "api.cuti-e.com" is)
        XCTAssertFalse(pinning.requiresPinning(for: "cuti-e.com"))
    }

    func testDoesNotRequirePinningForSimilarDomain() {
        let pinning = CutiECertificatePinning.shared
        XCTAssertFalse(pinning.requiresPinning(for: "evil-api.cuti-e.com.attacker.com"))
    }

    // MARK: - Expiry Monitoring Tests

    func testDaysUntilPinExpiryIsPositive() {
        // Pins expire June 22, 2036 - should be many years away
        let days = CutiECertificatePinning.daysUntilPinExpiry()
        XCTAssertGreaterThan(days, 365 * 9, "Pins should expire more than 9 years from now")
    }

    func testDaysUntilPinExpiryIsReasonable() {
        let days = CutiECertificatePinning.daysUntilPinExpiry()
        // Should be less than ~11 years from now (pins expire 2036)
        XCTAssertLessThan(days, 365 * 11, "Pins expiry should be within 11 years")
    }

    func testCheckPinExpiryDoesNotCrash() {
        // Just verify it doesn't crash - it only logs
        CutiECertificatePinning.checkPinExpiry()
    }

    // MARK: - Session Creation Tests

    func testCreatePinnedSessionReturnsSession() {
        let pinning = CutiECertificatePinning.shared
        let session = pinning.createPinnedSession()
        XCTAssertNotNil(session)
    }

    func testCreatePinnedSessionWithCustomConfig() {
        let pinning = CutiECertificatePinning.shared
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        let session = pinning.createPinnedSession(configuration: config)
        XCTAssertNotNil(session)
    }

    // MARK: - Singleton Tests

    func testSharedSingleton() {
        let instance1 = CutiECertificatePinning.shared
        let instance2 = CutiECertificatePinning.shared
        XCTAssertTrue(instance1 === instance2, "shared should return the same instance")
    }

    // MARK: - Certificate Validation Tests

    func testValidateCertificateChainWithNoTrust() {
        let pinning = CutiECertificatePinning.shared

        // Create an empty trust with no certificates
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        SecTrustCreateWithCertificates([] as CFArray, policy, &trust)

        if let trust = trust {
            // Empty certificate chain should fail validation
            XCTAssertFalse(pinning.validateCertificateChain(trust))
        }
    }
}
