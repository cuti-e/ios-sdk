import XCTest
@testable import CutiE

// MARK: - AppAttestError Tests

final class AppAttestErrorTests: XCTestCase {

    func testNotSupportedError() {
        let error = AppAttestError.notSupported
        XCTAssertEqual(error.errorDescription, "App Attest is not supported on this device")
    }

    func testNotAttestedError() {
        let error = AppAttestError.notAttested
        XCTAssertEqual(error.errorDescription, "Device not attested. Call performAttestation() first.")
    }

    func testHashingFailedError() {
        let error = AppAttestError.hashingFailed
        XCTAssertEqual(error.errorDescription, "Failed to create client data hash")
    }

    func testKeyGenerationFailedError() {
        let error = AppAttestError.keyGenerationFailed
        XCTAssertEqual(error.errorDescription, "Failed to generate key pair")
    }

    func testAttestationFailedError() {
        struct MockError: Error, LocalizedError {
            var errorDescription: String? { "Apple server rejected" }
        }

        let error = AppAttestError.attestationFailed(MockError())
        XCTAssertTrue(error.errorDescription?.contains("Attestation failed") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Apple server rejected") ?? false)
    }

    func testAssertionFailedError() {
        struct MockError: Error, LocalizedError {
            var errorDescription: String? { "Key not found" }
        }

        let error = AppAttestError.assertionFailed(MockError())
        XCTAssertTrue(error.errorDescription?.contains("Assertion generation failed") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Key not found") ?? false)
    }

    func testServerErrorMessage() {
        let error = AppAttestError.serverError("Invalid attestation object")
        XCTAssertEqual(error.errorDescription, "Server error: Invalid attestation object")
    }

    func testAllErrorsConformToLocalizedError() {
        let errors: [AppAttestError] = [
            .notSupported,
            .notAttested,
            .hashingFailed,
            .keyGenerationFailed,
            .attestationFailed(NSError(domain: "test", code: 0)),
            .assertionFailed(NSError(domain: "test", code: 0)),
            .serverError("test")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have errorDescription")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - AppAttest Behavior Tests

@available(iOS 14.0, macOS 11.0, *)
final class AppAttestTests: XCTestCase {

    func testSharedSingleton() {
        let instance1 = CutiEAppAttest.shared
        let instance2 = CutiEAppAttest.shared
        XCTAssertTrue(instance1 === instance2, "shared should return the same instance")
    }

    func testIsSupportedOnMacOS() {
        // On macOS test runner / simulator, isSupported should return false
        // (App Attest requires physical iOS device with Secure Enclave)
        #if targetEnvironment(simulator) || os(macOS)
        XCTAssertFalse(CutiEAppAttest.shared.isSupported)
        #endif
    }

    func testResetClearsAttestationState() {
        let appAttest = CutiEAppAttest.shared
        appAttest.reset()
        XCTAssertFalse(appAttest.isAttested, "After reset, isAttested should be false")
    }

    func testGenerateAssertionThrowsNotSupportedOnMacOS() async {
        #if targetEnvironment(simulator) || os(macOS)
        let appAttest = CutiEAppAttest.shared
        let testData = "test payload".data(using: .utf8)!

        do {
            _ = try await appAttest.generateAssertion(for: testData)
            XCTFail("Should throw on unsupported platform")
        } catch let error as AppAttestError {
            XCTAssertEqual(error.errorDescription, AppAttestError.notSupported.errorDescription)
        } catch {
            XCTFail("Expected AppAttestError.notSupported, got \(error)")
        }
        #endif
    }
}

// MARK: - AppAttest Model Tests

final class AppAttestModelTests: XCTestCase {

    func testAttestationStatusDecoding() throws {
        let json = """
        {
            "attested": true,
            "attestation": {
                "key_id": "abc123",
                "environment": "production",
                "sign_count": 5,
                "created_at": 1700000000,
                "last_assertion_at": 1700001000
            }
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(AttestationStatus.self, from: json)
        XCTAssertTrue(status.attested)
        XCTAssertNotNil(status.attestation)
        XCTAssertEqual(status.attestation?.keyId, "abc123")
        XCTAssertEqual(status.attestation?.environment, "production")
        XCTAssertEqual(status.attestation?.signCount, 5)
        XCTAssertEqual(status.attestation?.createdAt, 1700000000)
        XCTAssertEqual(status.attestation?.lastAssertionAt, 1700001000)
    }

    func testAttestationStatusDecodingNotAttested() throws {
        let json = """
        {
            "attested": false,
            "attestation": null
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(AttestationStatus.self, from: json)
        XCTAssertFalse(status.attested)
        XCTAssertNil(status.attestation)
    }

    func testAttestationInfoDecodingWithoutLastAssertion() throws {
        let json = """
        {
            "key_id": "key456",
            "environment": "development",
            "sign_count": 0,
            "created_at": 1700000000,
            "last_assertion_at": null
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(AttestationInfo.self, from: json)
        XCTAssertEqual(info.keyId, "key456")
        XCTAssertEqual(info.environment, "development")
        XCTAssertEqual(info.signCount, 0)
        XCTAssertEqual(info.createdAt, 1700000000)
        XCTAssertNil(info.lastAssertionAt)
    }

    func testAttestChallengeResponseDecoding() throws {
        let json = """
        {
            "challenge": "random-challenge-string-abc123",
            "expires_at": 1700001000,
            "expires_in": 300
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AttestChallengeResponse.self, from: json)
        XCTAssertEqual(response.challenge, "random-challenge-string-abc123")
        XCTAssertEqual(response.expiresAt, 1700001000)
        XCTAssertEqual(response.expiresIn, 300)
    }

    func testAttestResponseDecoding() throws {
        let json = """
        {
            "success": true,
            "attestation_id": "att_xyz789",
            "attested": true
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AttestResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.attestationId, "att_xyz789")
        XCTAssertTrue(response.attested)
    }

    func testAttestResponseDecodingFailure() throws {
        let json = """
        {
            "success": false,
            "attestation_id": "",
            "attested": false
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AttestResponse.self, from: json)
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.attestationId, "")
        XCTAssertFalse(response.attested)
    }
}

// MARK: - Data SHA256 Extension Tests

final class DataSHA256Tests: XCTestCase {

    func testSHA256ProducesCorrectLength() {
        let data = "Hello, World!".data(using: .utf8)!
        let hash = data.sha256()
        XCTAssertEqual(hash.count, 32, "SHA-256 should produce 32 bytes")
    }

    func testSHA256Consistency() {
        let data = "test data".data(using: .utf8)!
        let hash1 = data.sha256()
        let hash2 = data.sha256()
        XCTAssertEqual(hash1, hash2, "Same input should produce same hash")
    }

    func testSHA256DifferentInputs() {
        let data1 = "input one".data(using: .utf8)!
        let data2 = "input two".data(using: .utf8)!
        let hash1 = data1.sha256()
        let hash2 = data2.sha256()
        XCTAssertNotEqual(hash1, hash2, "Different inputs should produce different hashes")
    }

    func testSHA256EmptyData() {
        let data = Data()
        let hash = data.sha256()
        XCTAssertEqual(hash.count, 32, "SHA-256 of empty data should still be 32 bytes")

        // Known SHA-256 of empty string: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        let expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        let actual = hash.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(actual, expected)
    }

    func testSHA256KnownVector() {
        // Known: SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
        let data = "abc".data(using: .utf8)!
        let hash = data.sha256()
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
