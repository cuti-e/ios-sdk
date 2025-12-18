import XCTest
@testable import CutiE

@available(iOS 10.0, macOS 10.14, *)
final class PushNotificationTests: XCTestCase {

    // MARK: - Token Validation Tests

    func testValidToken_64Characters() {
        // Standard APNs token: 64 hex characters (32 bytes)
        let token = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNil(error, "Valid 64-character hex token should pass validation")
    }

    func testValidToken_MinimumLength() {
        // Minimum valid token: 32 characters
        let token = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNil(error, "32-character hex token should pass validation")
    }

    func testValidToken_UppercaseHex() {
        // Uppercase hex should be accepted
        let token = "A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2"
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNil(error, "Uppercase hex token should pass validation")
    }

    func testValidToken_MixedCaseHex() {
        // Mixed case hex should be accepted
        let token = "A1b2C3d4E5f6A1b2C3d4E5f6A1b2C3d4E5f6A1b2C3d4E5f6A1b2C3d4E5f6A1b2"
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNil(error, "Mixed case hex token should pass validation")
    }

    func testInvalidToken_Empty() {
        let error = CutiEPushNotifications.shared.validatePushToken("")
        XCTAssertNotNil(error, "Empty token should fail validation")
        if case .invalidPushToken(let reason) = error {
            XCTAssertTrue(reason.contains("empty"), "Error should mention empty token")
        } else {
            XCTFail("Expected invalidPushToken error")
        }
    }

    func testInvalidToken_TooShort() {
        // 31 characters (below minimum of 32)
        let token = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3"
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNotNil(error, "Token shorter than 32 characters should fail validation")
        if case .invalidPushToken(let reason) = error {
            XCTAssertTrue(reason.contains("short"), "Error should mention token is too short")
        } else {
            XCTFail("Expected invalidPushToken error")
        }
    }

    func testInvalidToken_TooLong() {
        // 201 characters (above maximum of 200)
        let token = String(repeating: "a", count: 201)
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNotNil(error, "Token longer than 200 characters should fail validation")
        if case .invalidPushToken(let reason) = error {
            XCTAssertTrue(reason.contains("long"), "Error should mention token is too long")
        } else {
            XCTFail("Expected invalidPushToken error")
        }
    }

    func testInvalidToken_NonHexCharacters() {
        // Token with non-hex characters (g, h, i, etc.)
        let token = "a1b2c3d4e5f6g7h8i9j0a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNotNil(error, "Token with non-hex characters should fail validation")
        if case .invalidPushToken(let reason) = error {
            XCTAssertTrue(reason.contains("hexadecimal"), "Error should mention hexadecimal format")
        } else {
            XCTFail("Expected invalidPushToken error")
        }
    }

    func testInvalidToken_WithSpaces() {
        let token = "a1b2 c3d4 e5f6 a1b2 c3d4 e5f6 a1b2 c3d4"
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNotNil(error, "Token with spaces should fail validation")
    }

    func testInvalidToken_WithSpecialCharacters() {
        let token = "a1b2c3d4e5f6!@#$a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNotNil(error, "Token with special characters should fail validation")
    }

    func testValidToken_MaximumLength() {
        // Maximum valid token: 200 characters
        let token = String(repeating: "a1", count: 100)
        XCTAssertEqual(token.count, 200)
        let error = CutiEPushNotifications.shared.validatePushToken(token)
        XCTAssertNil(error, "200-character hex token should pass validation")
    }

    // MARK: - Register Token Tests

    func testRegisterToken_ValidToken_ReturnsSuccess() {
        let token = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        let result = CutiEPushNotifications.shared.registerToken(token)

        switch result {
        case .success:
            // Expected
            break
        case .failure(let error):
            XCTFail("Valid token should succeed, got error: \(error)")
        }
    }

    func testRegisterToken_InvalidToken_ReturnsFailure() {
        let result = CutiEPushNotifications.shared.registerToken("")

        switch result {
        case .success:
            XCTFail("Empty token should fail validation")
        case .failure(let error):
            if case .invalidPushToken = error {
                // Expected
            } else {
                XCTFail("Expected invalidPushToken error, got: \(error)")
            }
        }
    }

    // MARK: - Error Description Tests

    func testInvalidPushTokenError_HasDescription() {
        let error = CutiEError.invalidPushToken("test reason")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("test reason") ?? false)
    }
}
