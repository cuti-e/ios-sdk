import XCTest
@testable import CutiE

final class CutiEAPIClientTests: XCTestCase {

    // MARK: - URL Construction Tests

    func testEndpointURLConstruction() {
        // Given
        let config = CutiEConfiguration(
            apiKey: "test_key",
            apiURL: "https://api.test.com",
            deviceID: "device_123",
            appId: "app_test123"
        )
        let client = CutiEAPIClient(configuration: config)

        // Test endpoint construction (would need to expose for testing or use mirror)
        // This is a basic structure test
        XCTAssertNotNil(client)
    }

    // MARK: - Request Header Tests

    func testRequestHeaders() {
        // Given
        let apiKey = "test_api_key_456"
        let deviceID = "device_test_789"
        let config = CutiEConfiguration(
            apiKey: apiKey,
            apiURL: "https://api.test.com",
            deviceID: deviceID,
            appId: "app_test456"
        )

        // When
        let client = CutiEAPIClient(configuration: config)

        // Then
        XCTAssertNotNil(client)
        // Headers would be verified in integration tests with a mock server
    }

    // MARK: - Device Signature Tests

    func testDeviceSignatureGeneration() {
        // Given
        let deviceID = "device_test_123"
        let timestamp = "1234567890"
        let salt = "test_salt_123"

        // When
        let signature = CutiEAPIClient.generateDeviceSignature(
            deviceID: deviceID,
            timestamp: timestamp,
            salt: salt
        )

        // Then
        XCTAssertNotNil(signature)
        XCTAssertFalse(signature.isEmpty)
        XCTAssertEqual(signature.count, 64) // SHA-256 produces 64 hex characters

        // Test consistency
        let signature2 = CutiEAPIClient.generateDeviceSignature(
            deviceID: deviceID,
            timestamp: timestamp,
            salt: salt
        )
        XCTAssertEqual(signature, signature2, "Same input should produce same signature")
    }

    func testDeviceSignatureDifferentInputs() {
        // Given
        let deviceID1 = "device_test_123"
        let deviceID2 = "device_test_456"
        let timestamp = "1234567890"
        let salt = "test_salt_123"

        // When
        let signature1 = CutiEAPIClient.generateDeviceSignature(
            deviceID: deviceID1,
            timestamp: timestamp,
            salt: salt
        )
        let signature2 = CutiEAPIClient.generateDeviceSignature(
            deviceID: deviceID2,
            timestamp: timestamp,
            salt: salt
        )

        // Then
        XCTAssertNotEqual(signature1, signature2, "Different device IDs should produce different signatures")
    }
}

// MARK: - Integration Tests (require live server or mock)

final class CutiEAPIIntegrationTests: XCTestCase {

    var cutiE: CutiE!

    override func setUp() {
        super.setUp()
        cutiE = CutiE.shared

        // Configure with sandbox/test credentials
        // These tests would only run if CUTIE_TEST_API_KEY environment variable is set
        guard let apiKey = ProcessInfo.processInfo.environment["CUTIE_TEST_API_KEY"],
              let appId = ProcessInfo.processInfo.environment["CUTIE_TEST_APP_ID"] else {
            return
        }

        cutiE.configure(
            apiKey: apiKey,
            appId: appId,
            apiURL: "https://cutie-worker-sandbox.invotekas.workers.dev"
        )
    }

    func testCreateConversation() throws {
        // Skip if test credentials are not set via environment variables
        guard ProcessInfo.processInfo.environment["CUTIE_TEST_API_KEY"] != nil,
              ProcessInfo.processInfo.environment["CUTIE_TEST_APP_ID"] != nil else {
            throw XCTSkip("Skipping integration test: CUTIE_TEST_API_KEY and CUTIE_TEST_APP_ID environment variables not set")
        }

        let expectation = XCTestExpectation(description: "Create conversation")

        cutiE.createConversation(
            category: .bug,
            message: "Test message from iOS SDK tests",
            title: "SDK Test Conversation"
        ) { result in
            switch result {
            case .success(let conversationId):
                XCTAssertFalse(conversationId.isEmpty)
                XCTAssertTrue(conversationId.hasPrefix("conv_"))
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to create conversation: \(error)")
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // testListConversations: Removed - listConversations method not implemented in v1.0.63 minimal SDK
}
