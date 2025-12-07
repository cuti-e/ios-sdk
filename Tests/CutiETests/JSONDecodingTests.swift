import XCTest
@testable import CutiE

final class JSONDecodingTests: XCTestCase {

    // MARK: - Conversation JSON Decoding

    func testConversationDecoding() throws {
        let json = """
        {
            "conversation_id": "conv_abc123",
            "customer_id": "cust_456",
            "user_id": "user_789",
            "user_name": "John Doe",
            "device_id": "device_xyz",
            "title": "Bug in login",
            "category": "bug",
            "status": "open",
            "priority": "high",
            "assigned_admin_id": "admin_1",
            "app_id": "app_test",
            "message_count": 5,
            "unread_count": 2,
            "created_at": 1700000000000,
            "updated_at": 1700000100000
        }
        """.data(using: .utf8)!

        let conversation = try JSONDecoder().decode(Conversation.self, from: json)

        XCTAssertEqual(conversation.id, "conv_abc123")
        XCTAssertEqual(conversation.customerID, "cust_456")
        XCTAssertEqual(conversation.userID, "user_789")
        XCTAssertEqual(conversation.userName, "John Doe")
        XCTAssertEqual(conversation.deviceID, "device_xyz")
        XCTAssertEqual(conversation.title, "Bug in login")
        XCTAssertEqual(conversation.category, .bug)
        XCTAssertEqual(conversation.status, .open)
        XCTAssertEqual(conversation.priority, .high)
        XCTAssertEqual(conversation.assignedAdminID, "admin_1")
        XCTAssertEqual(conversation.appId, "app_test")
        XCTAssertEqual(conversation.messageCount, 5)
        XCTAssertEqual(conversation.unreadCount, 2)
    }

    func testConversationDecodingAllStatuses() throws {
        let statuses = ["open", "in_progress", "waiting_user", "waiting_admin", "resolved", "closed"]
        let expected: [ConversationStatus] = [.open, .in_progress, .waiting_user, .waiting_admin, .resolved, .closed]

        for (status, expectedStatus) in zip(statuses, expected) {
            let json = """
            {
                "conversation_id": "conv_1",
                "status": "\(status)",
                "created_at": 1700000000000
            }
            """.data(using: .utf8)!

            let conversation = try JSONDecoder().decode(Conversation.self, from: json)
            XCTAssertEqual(conversation.status, expectedStatus, "Status '\(status)' should decode to \(expectedStatus)")
        }
    }

    func testConversationDecodingAllCategories() throws {
        let categories = ["bug", "feature", "question", "feedback", "other"]
        let expected: [ConversationCategory] = [.bug, .feature, .question, .feedback, .other]

        for (category, expectedCategory) in zip(categories, expected) {
            let json = """
            {
                "conversation_id": "conv_1",
                "category": "\(category)",
                "status": "open",
                "created_at": 1700000000000
            }
            """.data(using: .utf8)!

            let conversation = try JSONDecoder().decode(Conversation.self, from: json)
            XCTAssertEqual(conversation.category, expectedCategory, "Category '\(category)' should decode to \(expectedCategory)")
        }
    }

    func testConversationDecodingAllPriorities() throws {
        let priorities = ["low", "normal", "high", "urgent"]
        let expected: [ConversationPriority] = [.low, .normal, .high, .urgent]

        for (priority, expectedPriority) in zip(priorities, expected) {
            let json = """
            {
                "conversation_id": "conv_1",
                "priority": "\(priority)",
                "status": "open",
                "created_at": 1700000000000
            }
            """.data(using: .utf8)!

            let conversation = try JSONDecoder().decode(Conversation.self, from: json)
            XCTAssertEqual(conversation.priority, expectedPriority, "Priority '\(priority)' should decode to \(expectedPriority)")
        }
    }

    func testConversationDecodingWithMessages() throws {
        let json = """
        {
            "conversation_id": "conv_1",
            "status": "open",
            "created_at": 1700000000000,
            "messages": [
                {
                    "message_id": "msg_1",
                    "conversation_id": "conv_1",
                    "sender_type": "user",
                    "message": "Hello",
                    "message_type": "text",
                    "is_internal_note": false,
                    "created_at": 1700000000000
                },
                {
                    "message_id": "msg_2",
                    "conversation_id": "conv_1",
                    "sender_type": "admin",
                    "message": "Hi there!",
                    "message_type": "text",
                    "is_internal_note": false,
                    "created_at": 1700000050000
                }
            ]
        }
        """.data(using: .utf8)!

        let conversation = try JSONDecoder().decode(Conversation.self, from: json)

        XCTAssertNotNil(conversation.messages)
        XCTAssertEqual(conversation.messages?.count, 2)
        XCTAssertEqual(conversation.messages?[0].message, "Hello")
        XCTAssertEqual(conversation.messages?[1].message, "Hi there!")
    }

    func testConversationDecodingWithTags() throws {
        let json = """
        {
            "conversation_id": "conv_1",
            "status": "open",
            "created_at": 1700000000000,
            "tags": [
                {
                    "tag_id": "tag_1",
                    "conversation_id": "conv_1",
                    "tag_name": "urgent",
                    "tag_color": "#FF0000"
                }
            ]
        }
        """.data(using: .utf8)!

        let conversation = try JSONDecoder().decode(Conversation.self, from: json)

        XCTAssertNotNil(conversation.tags)
        XCTAssertEqual(conversation.tags?.count, 1)
        XCTAssertEqual(conversation.tags?[0].tagName, "urgent")
    }

    func testConversationDecodingMinimalFields() throws {
        let json = """
        {
            "conversation_id": "conv_minimal",
            "status": "open",
            "created_at": 1700000000000
        }
        """.data(using: .utf8)!

        let conversation = try JSONDecoder().decode(Conversation.self, from: json)

        XCTAssertEqual(conversation.id, "conv_minimal")
        XCTAssertEqual(conversation.status, .open)
        XCTAssertNil(conversation.customerID)
        XCTAssertNil(conversation.userID)
        XCTAssertNil(conversation.userName)
        XCTAssertNil(conversation.deviceID)
        XCTAssertNil(conversation.title)
        XCTAssertNil(conversation.category)
        XCTAssertNil(conversation.priority)
        XCTAssertNil(conversation.assignedAdminID)
        XCTAssertNil(conversation.appId)
        XCTAssertNil(conversation.messageCount)
        XCTAssertNil(conversation.unreadCount)
        XCTAssertNil(conversation.messages)
        XCTAssertNil(conversation.tags)
        XCTAssertNil(conversation.updatedAt)
    }

    // MARK: - Message JSON Decoding

    func testMessageDecoding() throws {
        let json = """
        {
            "message_id": "msg_abc",
            "conversation_id": "conv_123",
            "sender_type": "user",
            "sender_id": "user_xyz",
            "sender_name": "John",
            "sender_avatar_url": "https://example.com/avatar.png",
            "message": "This is my feedback",
            "message_type": "text",
            "is_internal_note": false,
            "created_at": 1700000000000
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(Message.self, from: json)

        XCTAssertEqual(message.id, "msg_abc")
        XCTAssertEqual(message.conversationID, "conv_123")
        XCTAssertEqual(message.senderType, .user)
        XCTAssertEqual(message.senderID, "user_xyz")
        XCTAssertEqual(message.senderName, "John")
        XCTAssertEqual(message.senderAvatarUrl, "https://example.com/avatar.png")
        XCTAssertEqual(message.message, "This is my feedback")
        XCTAssertEqual(message.messageType, "text")
        XCTAssertFalse(message.isInternalNote)
    }

    func testMessageDecodingInternalNote() throws {
        let json = """
        {
            "message_id": "msg_internal",
            "conversation_id": "conv_123",
            "sender_type": "admin",
            "message": "Internal note for team",
            "message_type": "text",
            "is_internal_note": true,
            "created_at": 1700000000000
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(Message.self, from: json)

        XCTAssertTrue(message.isInternalNote)
        XCTAssertEqual(message.senderType, .admin)
    }

    func testMessageDecodingSystemMessage() throws {
        let json = """
        {
            "message_id": "msg_system",
            "conversation_id": "conv_123",
            "sender_type": "system",
            "message": "Status changed to resolved",
            "message_type": "text",
            "is_internal_note": false,
            "created_at": 1700000000000
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(Message.self, from: json)

        XCTAssertEqual(message.senderType, .system)
    }

    // MARK: - CreateConversationResponse Tests

    func testCreateConversationResponseDecoding() throws {
        let json = """
        {
            "conversation_id": "conv_new",
            "status": "open",
            "message_id": "msg_initial",
            "created_at": 1700000000000
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        XCTAssertEqual(response.conversationId, "conv_new")
        XCTAssertEqual(response.status, "open")
        XCTAssertEqual(response.messageId, "msg_initial")
        XCTAssertEqual(response.createdAt, 1700000000000)
    }

    func testCreateConversationResponseStatusConversion() throws {
        let json = """
        {
            "conversation_id": "conv_1",
            "status": "in_progress"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        XCTAssertEqual(response.conversationStatus, .in_progress)
    }

    func testCreateConversationResponseDefaultStatus() throws {
        let json = """
        {
            "conversation_id": "conv_1"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        // When status is nil, should default to .open
        XCTAssertEqual(response.conversationStatus, .open)
    }

    func testCreateConversationResponseInvalidStatus() throws {
        let json = """
        {
            "conversation_id": "conv_1",
            "status": "invalid_status"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        // When status is invalid, should default to .open
        XCTAssertEqual(response.conversationStatus, .open)
    }

    func testCreateConversationResponseCreatedAtFallback() throws {
        let json = """
        {
            "conversation_id": "conv_1"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        // When createdAt is nil, should return current timestamp
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        // Allow 1 second tolerance
        XCTAssertTrue(abs(response.createdAtInt64 - now) < 1000, "Created at should be close to current time")
    }
}
