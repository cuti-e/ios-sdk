import XCTest
@testable import CutiE

final class ModelTests: XCTestCase {

    // MARK: - Conversation Tests

    func testConversationCreation() {
        let conversation = Conversation(
            id: "conv_123",
            customerID: "cust_456",
            userID: "user_789",
            userName: "John Doe",
            deviceID: "device_abc",
            title: "Test Issue",
            category: .bug,
            status: .open,
            priority: .high,
            appId: "app_test",
            messageCount: 5,
            unreadCount: 2,
            createdAt: 1700000000000,
            updatedAt: 1700000100000
        )

        XCTAssertEqual(conversation.id, "conv_123")
        XCTAssertEqual(conversation.customerID, "cust_456")
        XCTAssertEqual(conversation.userID, "user_789")
        XCTAssertEqual(conversation.userName, "John Doe")
        XCTAssertEqual(conversation.deviceID, "device_abc")
        XCTAssertEqual(conversation.title, "Test Issue")
        XCTAssertEqual(conversation.category, .bug)
        XCTAssertEqual(conversation.status, .open)
        XCTAssertEqual(conversation.priority, .high)
        XCTAssertEqual(conversation.appId, "app_test")
        XCTAssertEqual(conversation.messageCount, 5)
        XCTAssertEqual(conversation.unreadCount, 2)
    }

    func testConversationHasUnread() {
        let withUnread = Conversation(
            id: "1",
            status: .open,
            unreadCount: 3,
            createdAt: 1700000000000
        )
        XCTAssertTrue(withUnread.hasUnread)

        let withoutUnread = Conversation(
            id: "2",
            status: .open,
            unreadCount: 0,
            createdAt: 1700000000000
        )
        XCTAssertFalse(withoutUnread.hasUnread)

        let nilUnread = Conversation(
            id: "3",
            status: .open,
            createdAt: 1700000000000
        )
        XCTAssertFalse(nilUnread.hasUnread)
    }

    func testConversationDateConversions() {
        // Test timestamp: 1700000000000 ms = November 14, 2023 22:13:20 UTC
        let conversation = Conversation(
            id: "1",
            status: .open,
            createdAt: 1700000000000,
            updatedAt: 1700000100000
        )

        let expectedCreatedDate = Date(timeIntervalSince1970: 1700000000)
        let expectedUpdatedDate = Date(timeIntervalSince1970: 1700000100)

        XCTAssertEqual(conversation.createdDate, expectedCreatedDate)
        XCTAssertEqual(conversation.updatedDate, expectedUpdatedDate)
    }

    func testConversationUpdatedDateFallback() {
        let conversation = Conversation(
            id: "1",
            status: .open,
            createdAt: 1700000000000,
            updatedAt: nil
        )

        // When updatedAt is nil, should fall back to createdAt
        let expectedDate = Date(timeIntervalSince1970: 1700000000)
        XCTAssertEqual(conversation.updatedDate, expectedDate)
    }

    // MARK: - Message Tests

    func testMessageCreation() {
        let message = Message(
            id: "msg_123",
            conversationID: "conv_456",
            senderType: .user,
            senderID: "user_789",
            senderName: "John",
            senderAvatarUrl: "https://example.com/avatar.png",
            message: "Hello, this is my feedback",
            messageType: "text",
            isInternalNote: false,
            createdAt: 1700000000000
        )

        XCTAssertEqual(message.id, "msg_123")
        XCTAssertEqual(message.conversationID, "conv_456")
        XCTAssertEqual(message.senderType, .user)
        XCTAssertEqual(message.senderID, "user_789")
        XCTAssertEqual(message.senderName, "John")
        XCTAssertEqual(message.senderAvatarUrl, "https://example.com/avatar.png")
        XCTAssertEqual(message.message, "Hello, this is my feedback")
        XCTAssertEqual(message.messageType, "text")
        XCTAssertFalse(message.isInternalNote)
    }

    func testMessageDateConversion() {
        let message = Message(
            id: "1",
            conversationID: "conv_1",
            senderType: .admin,
            message: "Response",
            createdAt: 1700000000000
        )

        let expectedDate = Date(timeIntervalSince1970: 1700000000)
        XCTAssertEqual(message.createdDate, expectedDate)
    }

    func testMessageSenderTypes() {
        let userMessage = Message(
            id: "1",
            conversationID: "conv_1",
            senderType: .user,
            message: "User msg",
            createdAt: 1700000000000
        )
        XCTAssertEqual(userMessage.senderType, .user)

        let adminMessage = Message(
            id: "2",
            conversationID: "conv_1",
            senderType: .admin,
            message: "Admin msg",
            createdAt: 1700000000000
        )
        XCTAssertEqual(adminMessage.senderType, .admin)

        let systemMessage = Message(
            id: "3",
            conversationID: "conv_1",
            senderType: .system,
            message: "System msg",
            createdAt: 1700000000000
        )
        XCTAssertEqual(systemMessage.senderType, .system)
    }

    // MARK: - SenderType Tests

    func testSenderTypeRawValues() {
        XCTAssertEqual(SenderType.user.rawValue, "user")
        XCTAssertEqual(SenderType.admin.rawValue, "admin")
        XCTAssertEqual(SenderType.system.rawValue, "system")
    }

    // MARK: - ConversationCategory Tests

    func testConversationCategoryColors() {
        XCTAssertEqual(ConversationCategory.bug.color, "red")
        XCTAssertEqual(ConversationCategory.feature.color, "purple")
        XCTAssertEqual(ConversationCategory.question.color, "blue")
        XCTAssertEqual(ConversationCategory.feedback.color, "green")
        XCTAssertEqual(ConversationCategory.other.color, "gray")
    }

    func testConversationCategoryCaseIterable() {
        let allCases = ConversationCategory.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.bug))
        XCTAssertTrue(allCases.contains(.feature))
        XCTAssertTrue(allCases.contains(.question))
        XCTAssertTrue(allCases.contains(.feedback))
        XCTAssertTrue(allCases.contains(.other))
    }

    func testConversationCategoryRawValues() {
        XCTAssertEqual(ConversationCategory.bug.rawValue, "bug")
        XCTAssertEqual(ConversationCategory.feature.rawValue, "feature")
        XCTAssertEqual(ConversationCategory.question.rawValue, "question")
        XCTAssertEqual(ConversationCategory.feedback.rawValue, "feedback")
        XCTAssertEqual(ConversationCategory.other.rawValue, "other")
    }

    // MARK: - ConversationStatus Tests

    func testConversationStatusColors() {
        XCTAssertEqual(ConversationStatus.open.color, "blue")
        XCTAssertEqual(ConversationStatus.in_progress.color, "orange")
        XCTAssertEqual(ConversationStatus.waiting_user.color, "yellow")
        XCTAssertEqual(ConversationStatus.waiting_admin.color, "red")
        XCTAssertEqual(ConversationStatus.resolved.color, "green")
        XCTAssertEqual(ConversationStatus.closed.color, "gray")
    }

    func testConversationStatusCaseIterable() {
        let allCases = ConversationStatus.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.open))
        XCTAssertTrue(allCases.contains(.in_progress))
        XCTAssertTrue(allCases.contains(.waiting_user))
        XCTAssertTrue(allCases.contains(.waiting_admin))
        XCTAssertTrue(allCases.contains(.resolved))
        XCTAssertTrue(allCases.contains(.closed))
    }

    func testConversationStatusRawValues() {
        XCTAssertEqual(ConversationStatus.open.rawValue, "open")
        XCTAssertEqual(ConversationStatus.in_progress.rawValue, "in_progress")
        XCTAssertEqual(ConversationStatus.waiting_user.rawValue, "waiting_user")
        XCTAssertEqual(ConversationStatus.waiting_admin.rawValue, "waiting_admin")
        XCTAssertEqual(ConversationStatus.resolved.rawValue, "resolved")
        XCTAssertEqual(ConversationStatus.closed.rawValue, "closed")
    }

    // MARK: - ConversationPriority Tests

    func testConversationPriorityColors() {
        XCTAssertEqual(ConversationPriority.low.color, "gray")
        XCTAssertEqual(ConversationPriority.normal.color, "blue")
        XCTAssertEqual(ConversationPriority.high.color, "orange")
        XCTAssertEqual(ConversationPriority.urgent.color, "red")
    }

    func testConversationPriorityCaseIterable() {
        let allCases = ConversationPriority.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.low))
        XCTAssertTrue(allCases.contains(.normal))
        XCTAssertTrue(allCases.contains(.high))
        XCTAssertTrue(allCases.contains(.urgent))
    }

    func testConversationPriorityRawValues() {
        XCTAssertEqual(ConversationPriority.low.rawValue, "low")
        XCTAssertEqual(ConversationPriority.normal.rawValue, "normal")
        XCTAssertEqual(ConversationPriority.high.rawValue, "high")
        XCTAssertEqual(ConversationPriority.urgent.rawValue, "urgent")
    }

    // MARK: - Tag Tests

    func testTagDecoding() throws {
        let json = """
        {
            "tag_id": "tag_123",
            "conversation_id": "conv_456",
            "tag_name": "important",
            "tag_color": "#FF0000"
        }
        """.data(using: .utf8)!

        let tag = try JSONDecoder().decode(Tag.self, from: json)

        XCTAssertEqual(tag.id, "tag_123")
        XCTAssertEqual(tag.conversationID, "conv_456")
        XCTAssertEqual(tag.tagName, "important")
        XCTAssertEqual(tag.tagColor, "#FF0000")
    }

    func testTagDecodingWithNilColor() throws {
        let json = """
        {
            "tag_id": "tag_123",
            "conversation_id": "conv_456",
            "tag_name": "important",
            "tag_color": null
        }
        """.data(using: .utf8)!

        let tag = try JSONDecoder().decode(Tag.self, from: json)

        XCTAssertEqual(tag.id, "tag_123")
        XCTAssertNil(tag.tagColor)
    }
}
