import XCTest
@testable import CutiE

final class ErrorTests: XCTestCase {

    // MARK: - CutiEError Tests

    func testNotConfiguredError() {
        let error = CutiEError.notConfigured
        XCTAssertEqual(error.errorDescription, "CutiE is not configured. Call CutiE.shared.configure() first.")
    }

    func testInvalidAPIKeyError() {
        let error = CutiEError.invalidAPIKey
        XCTAssertEqual(error.errorDescription, "Invalid API key")
    }

    func testNetworkError() {
        struct MockError: Error, LocalizedError {
            var errorDescription: String? { "Connection failed" }
        }

        let underlyingError = MockError()
        let error = CutiEError.networkError(underlyingError)

        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Connection failed") ?? false)
    }

    func testServerError() {
        let error = CutiEError.serverError(500, "Internal server error")
        XCTAssertEqual(error.errorDescription, "Server error (500): Internal server error")
    }

    func testServerErrorVariousCodes() {
        let error400 = CutiEError.serverError(400, "Bad request")
        XCTAssertTrue(error400.errorDescription?.contains("400") ?? false)

        let error401 = CutiEError.serverError(401, "Unauthorized")
        XCTAssertTrue(error401.errorDescription?.contains("401") ?? false)

        let error403 = CutiEError.serverError(403, "Forbidden")
        XCTAssertTrue(error403.errorDescription?.contains("403") ?? false)

        let error404 = CutiEError.serverError(404, "Not found")
        XCTAssertTrue(error404.errorDescription?.contains("404") ?? false)
    }

    func testDecodingErrorWithDetails() {
        let error = CutiEError.decodingError("Missing required field: conversation_id")
        XCTAssertEqual(error.errorDescription, "Missing required field: conversation_id")
    }

    func testDecodingErrorWithoutDetails() {
        let error = CutiEError.decodingError(nil)
        XCTAssertEqual(error.errorDescription, "Failed to decode server response")
    }

    func testDecodingErrorDefault() {
        let error = CutiEError.decodingError()
        XCTAssertEqual(error.errorDescription, "Failed to decode server response")
    }

    func testInvalidRequestError() {
        let error = CutiEError.invalidRequest
        XCTAssertEqual(error.errorDescription, "Invalid request")
    }

    // MARK: - LocalizedError Conformance

    func testErrorsConformToLocalizedError() {
        let errors: [CutiEError] = [
            .notConfigured,
            .invalidAPIKey,
            .networkError(NSError(domain: "test", code: 0)),
            .serverError(500, "test"),
            .decodingError("test"),
            .invalidRequest
        ]

        for error in errors {
            // All errors should have a non-nil errorDescription
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have errorDescription")
        }
    }
}

final class ConfigurationTests: XCTestCase {

    func testConfigureWithAppId() {
        let cutiE = CutiE.shared

        cutiE.configure(appId: "app_test123")

        XCTAssertTrue(cutiE.isConfigured)
        XCTAssertNotNil(cutiE.configuration)
        XCTAssertEqual(cutiE.configuration?.appId, "app_test123")
        XCTAssertEqual(cutiE.configuration?.apiURL, "https://api.cuti-e.com")
        XCTAssertFalse(cutiE.configuration?.useAppAttest ?? true)
    }

    func testConfigureWithCustomApiURL() {
        let cutiE = CutiE.shared

        cutiE.configure(appId: "app_test", apiURL: "https://custom.api.com")

        XCTAssertEqual(cutiE.configuration?.apiURL, "https://custom.api.com")
    }

    func testConfigureWithAppAttest() {
        let cutiE = CutiE.shared

        cutiE.configure(appId: "app_test", useAppAttest: true)

        XCTAssertTrue(cutiE.configuration?.useAppAttest ?? false)
    }

    func testDeviceIDPersistence() {
        let cutiE = CutiE.shared

        cutiE.configure(appId: "app_test1")
        let deviceID1 = cutiE.configuration?.deviceID

        cutiE.configure(appId: "app_test2")
        let deviceID2 = cutiE.configuration?.deviceID

        XCTAssertNotNil(deviceID1)
        XCTAssertEqual(deviceID1, deviceID2, "Device ID should persist across configurations")
        XCTAssertTrue(deviceID1?.hasPrefix("device_") ?? false)
    }

    func testSetUserID() {
        let cutiE = CutiE.shared
        cutiE.configure(appId: "app_test")

        cutiE.setUserID("user_123")
        XCTAssertEqual(cutiE.configuration?.userID, "user_123")

        cutiE.setUserID(nil)
        XCTAssertNil(cutiE.configuration?.userID)
    }

    func testSetUserId() {
        let cutiE = CutiE.shared
        cutiE.configure(appId: "app_test")

        // Test alias method
        cutiE.setUserId("user_456")
        XCTAssertEqual(cutiE.configuration?.userID, "user_456")
    }

    func testSetUserName() {
        let cutiE = CutiE.shared
        cutiE.configure(appId: "app_test")

        cutiE.setUserName("John Doe")
        XCTAssertEqual(cutiE.configuration?.userName, "John Doe")

        cutiE.setUserName(nil)
        XCTAssertNil(cutiE.configuration?.userName)
    }

    func testSetAppMetadata() {
        let cutiE = CutiE.shared
        cutiE.configure(appId: "app_test")

        cutiE.setAppMetadata(version: "1.2.3", build: "100")

        XCTAssertEqual(cutiE.configuration?.appVersion, "1.2.3")
        XCTAssertEqual(cutiE.configuration?.appBuild, "100")
    }

    func testIsConfiguredFalseBeforeConfiguration() {
        // Create a new reference and clear existing config
        let cutiE = CutiE.shared
        cutiE.configuration = nil
        cutiE.apiClient = nil

        XCTAssertFalse(cutiE.isConfigured)
    }

    func testCutiEConfigurationClass() {
        let config = CutiEConfiguration(
            apiKey: nil,
            apiURL: "https://api.test.com",
            deviceID: "device_test",
            appId: "app_test",
            useAppAttest: true
        )

        XCTAssertNil(config.apiKey)
        XCTAssertEqual(config.apiURL, "https://api.test.com")
        XCTAssertEqual(config.deviceID, "device_test")
        XCTAssertEqual(config.appId, "app_test")
        XCTAssertTrue(config.useAppAttest)
    }

    func testCutiEConfigurationWithApiKey() {
        let config = CutiEConfiguration(
            apiKey: "key_legacy",
            apiURL: "https://api.test.com",
            deviceID: "device_test",
            appId: "app_test",
            useAppAttest: false
        )

        XCTAssertEqual(config.apiKey, "key_legacy")
        XCTAssertFalse(config.useAppAttest)
    }
}
