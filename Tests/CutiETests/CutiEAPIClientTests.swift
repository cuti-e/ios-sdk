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

// MARK: - SDK Version Header Tests

final class SDKVersionHeaderTests: XCTestCase {

    func testSDKVersionConstantIsValid() {
        // Verify the SDK version constant exists and is in the expected format
        let sdkVersion = CutiE.sdkVersion

        XCTAssertFalse(sdkVersion.isEmpty, "SDK version should not be empty")
        XCTAssertTrue(
            sdkVersion.contains("."),
            "SDK version should be in semantic versioning format (e.g., 1.0.104)"
        )

        // Verify it's a valid semantic version (major.minor.patch)
        let components = sdkVersion.split(separator: ".")
        XCTAssertGreaterThanOrEqual(
            components.count,
            2,
            "SDK version should have at least major.minor components"
        )

        // Verify all components are numeric
        for component in components {
            XCTAssertNotNil(
                Int(component),
                "SDK version component '\(component)' should be numeric"
            )
        }
    }

    func testSDKVersionHeaderCanBeSetOnRequest() {
        // Verify that the SDK version can be set as a header on a URLRequest
        // This mirrors the implementation in CutiEAPIClient.performRequest (line 692)
        // and CutiEAPIClient.registerDeviceToken (line 94)

        let testURL = URL(string: "https://api.test.com/v1/conversations")!
        var request = URLRequest(url: testURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Set the SDK version header as done in the actual implementation
        request.setValue(CutiE.sdkVersion, forHTTPHeaderField: "X-CutiE-SDK-Version")

        // Verify the header is present and matches the constant
        let sdkVersionHeader = request.value(forHTTPHeaderField: "X-CutiE-SDK-Version")
        XCTAssertNotNil(sdkVersionHeader, "X-CutiE-SDK-Version header should be present")
        XCTAssertEqual(
            sdkVersionHeader,
            CutiE.sdkVersion,
            "X-CutiE-SDK-Version header should equal CutiE.sdkVersion"
        )
        XCTAssertFalse(sdkVersionHeader!.isEmpty, "SDK version header value should not be empty")
    }

    func testSDKVersionHeaderNameIsCorrect() {
        // Verify the expected header name is used
        let expectedHeaderName = "X-CutiE-SDK-Version"

        // Create a request and set the header
        let testURL = URL(string: "https://api.test.com")!
        var request = URLRequest(url: testURL)
        request.setValue("1.0.0", forHTTPHeaderField: expectedHeaderName)

        // Verify it can be retrieved with the exact name
        XCTAssertNotNil(
            request.value(forHTTPHeaderField: expectedHeaderName),
            "Header should be retrievable with name '\(expectedHeaderName)'"
        )

        // Verify the header name is case-insensitive (HTTP header standard)
        XCTAssertNotNil(
            request.value(forHTTPHeaderField: "x-cutie-sdk-version"),
            "HTTP headers should be case-insensitive"
        )
    }
}
