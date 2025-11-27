import XCTest
@testable import CutiE

final class CutiETests: XCTestCase {

    var cutiE: CutiE!

    override func setUp() {
        super.setUp()
        cutiE = CutiE.shared
    }

    override func tearDown() {
        cutiE = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testConfiguration() {
        // Given
        let apiKey = "test_api_key_123"
        let appId = "app_test123"
        let apiURL = "https://test.api.com"

        // When
        cutiE.configure(apiKey: apiKey, appId: appId, apiURL: apiURL)

        // Then
        XCTAssertNotNil(cutiE.configuration)
        XCTAssertEqual(cutiE.configuration?.apiKey, apiKey)
        XCTAssertEqual(cutiE.configuration?.apiURL, apiURL)
        XCTAssertEqual(cutiE.configuration?.appId, appId)
    }

    func testDefaultAPIURL() {
        // Given
        let apiKey = "test_api_key_123"
        let appId = "app_test123"

        // When
        cutiE.configure(apiKey: apiKey, appId: appId)

        // Then
        XCTAssertEqual(cutiE.configuration?.apiURL, "https://api.cuti-e.com")
    }

    func testDeviceIDGeneration() {
        // Given
        let apiKey = "test_api_key_123"
        let appId = "app_test123"

        // When
        cutiE.configure(apiKey: apiKey, appId: appId)
        let deviceID1 = cutiE.configuration?.deviceID

        // Configure again
        cutiE.configure(apiKey: apiKey, appId: appId)
        let deviceID2 = cutiE.configuration?.deviceID

        // Then
        XCTAssertNotNil(deviceID1)
        XCTAssertTrue(deviceID1?.hasPrefix("device_") ?? false)
        XCTAssertEqual(deviceID1, deviceID2, "Device ID should persist")
    }

    // MARK: - Error Tests

    func testOperationsWithoutConfiguration() {
        // Given
        // Create a new instance (not the shared singleton)
        // Since init is private, we'll use the shared instance but clear its config
        let expectation = XCTestExpectation(description: "Error callback")

        // Save current config
        let savedConfig = CutiE.shared.configuration
        CutiE.shared.configuration = nil
        CutiE.shared.apiClient = nil

        // When
        CutiE.shared.createConversation(
            category: ConversationCategory.bug,
            message: "Test",
            title: "Test"
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Should fail without configuration")
            case .failure(let error):
                if case CutiEError.notConfigured = error {
                    expectation.fulfill()
                } else {
                    XCTFail("Wrong error type")
                }
            }
        }

        wait(for: [expectation], timeout: 1.0)

        // Restore config
        CutiE.shared.configuration = savedConfig
        if let config = savedConfig {
            CutiE.shared.apiClient = CutiEAPIClient(configuration: config)
        }
    }

    // MARK: - Model Tests

    func testConversationCategoryDisplayNames() {
        XCTAssertEqual(ConversationCategory.bug.displayName, "Bug Report")
        XCTAssertEqual(ConversationCategory.feature.displayName, "Feature Request")
        XCTAssertEqual(ConversationCategory.question.displayName, "Question")
        XCTAssertEqual(ConversationCategory.feedback.displayName, "Feedback")
        XCTAssertEqual(ConversationCategory.other.displayName, "Other")
    }

    func testConversationCategoryEmojis() {
        XCTAssertEqual(ConversationCategory.bug.emoji, "🐛")
        XCTAssertEqual(ConversationCategory.feature.emoji, "✨")
        XCTAssertEqual(ConversationCategory.question.emoji, "❓")
        XCTAssertEqual(ConversationCategory.feedback.emoji, "💬")
        XCTAssertEqual(ConversationCategory.other.emoji, "📝")
    }

    func testConversationStatusDisplayNames() {
        XCTAssertEqual(ConversationStatus.open.displayName, "Open")
        XCTAssertEqual(ConversationStatus.in_progress.displayName, "In Progress")
        XCTAssertEqual(ConversationStatus.waiting_user.displayName, "Waiting for User")
        XCTAssertEqual(ConversationStatus.waiting_admin.displayName, "Waiting for Admin")
        XCTAssertEqual(ConversationStatus.resolved.displayName, "Resolved")
        XCTAssertEqual(ConversationStatus.closed.displayName, "Closed")
    }

    func testConversationPriorityDisplayNames() {
        XCTAssertEqual(ConversationPriority.low.displayName, "Low")
        XCTAssertEqual(ConversationPriority.normal.displayName, "Normal")
        XCTAssertEqual(ConversationPriority.high.displayName, "High")
        XCTAssertEqual(ConversationPriority.urgent.displayName, "Urgent")
    }

    // MARK: - Singleton Tests

    func testSharedInstance() {
        let instance1 = CutiE.shared
        let instance2 = CutiE.shared

        XCTAssertTrue(instance1 === instance2, "Shared should return same instance")
    }
}
