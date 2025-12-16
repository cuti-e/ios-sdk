import XCTest
@testable import CutiE

/// Tests for API response contract validation
/// These tests verify that our models correctly parse expected API responses
final class APIContractTests: XCTestCase {

    // MARK: - CreateConversation Response

    func testCreateConversationResponseDecoding() throws {
        let json = """
        {
            "conversation_id": "conv_abc123",
            "status": "open",
            "message_id": "msg_001",
            "created_at": 1702734000
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        XCTAssertEqual(response.conversationId, "conv_abc123")
        XCTAssertEqual(response.status, "open")
        XCTAssertEqual(response.messageId, "msg_001")
        XCTAssertEqual(response.createdAt, 1702734000)
    }

    func testCreateConversationResponseMinimal() throws {
        // Minimal response with only required field
        let json = """
        {
            "conversation_id": "conv_minimal"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        XCTAssertEqual(response.conversationId, "conv_minimal")
        XCTAssertNil(response.status)
        XCTAssertNil(response.messageId)
        XCTAssertNil(response.createdAt)
    }

    func testCreateConversationResponseConversationStatus() throws {
        let json = """
        {
            "conversation_id": "conv_test",
            "status": "in_progress"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        XCTAssertEqual(response.conversationStatus, .in_progress)
    }

    func testCreateConversationResponseDefaultsToOpenStatus() throws {
        let json = """
        {
            "conversation_id": "conv_test"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateConversationResponse.self, from: json)

        // Should default to .open when status is missing
        XCTAssertEqual(response.conversationStatus, .open)
    }

    // MARK: - Conversation Model

    func testConversationDecoding() throws {
        let json = """
        {
            "conversation_id": "conv_full123",
            "customer_id": "cust_456",
            "user_id": "user_789",
            "user_name": "John Doe",
            "device_id": "device_abc",
            "title": "Test Conversation",
            "category": "bug",
            "status": "open",
            "priority": "high",
            "assigned_admin_id": "admin_001",
            "app_id": "app_test",
            "message_count": 5,
            "unread_count": 2,
            "created_at": 1702734000000,
            "updated_at": 1702734100000
        }
        """.data(using: .utf8)!

        let conversation = try JSONDecoder().decode(Conversation.self, from: json)

        XCTAssertEqual(conversation.id, "conv_full123")
        XCTAssertEqual(conversation.customerID, "cust_456")
        XCTAssertEqual(conversation.userID, "user_789")
        XCTAssertEqual(conversation.userName, "John Doe")
        XCTAssertEqual(conversation.deviceID, "device_abc")
        XCTAssertEqual(conversation.title, "Test Conversation")
        XCTAssertEqual(conversation.category, .bug)
        XCTAssertEqual(conversation.status, .open)
        XCTAssertEqual(conversation.priority, .high)
        XCTAssertEqual(conversation.assignedAdminID, "admin_001")
        XCTAssertEqual(conversation.appId, "app_test")
        XCTAssertEqual(conversation.messageCount, 5)
        XCTAssertEqual(conversation.unreadCount, 2)
        XCTAssertTrue(conversation.hasUnread)
    }

    func testConversationMinimalDecoding() throws {
        // API may return minimal conversation data
        let json = """
        {
            "conversation_id": "conv_min",
            "status": "open",
            "created_at": 1702734000000
        }
        """.data(using: .utf8)!

        let conversation = try JSONDecoder().decode(Conversation.self, from: json)

        XCTAssertEqual(conversation.id, "conv_min")
        XCTAssertEqual(conversation.status, .open)
        XCTAssertNil(conversation.title)
        XCTAssertNil(conversation.userID)
        XCTAssertNil(conversation.category)
    }

    func testConversationWithTags() throws {
        let json = """
        {
            "conversation_id": "conv_tags",
            "status": "open",
            "created_at": 1702734000000,
            "tags": [
                {
                    "tag_id": "tag1",
                    "conversation_id": "conv_tags",
                    "tag_name": "urgent",
                    "tag_color": "#ff0000"
                }
            ]
        }
        """.data(using: .utf8)!

        let conversation = try JSONDecoder().decode(Conversation.self, from: json)

        XCTAssertEqual(conversation.tags?.count, 1)
        XCTAssertEqual(conversation.tags?.first?.tagName, "urgent")
        XCTAssertEqual(conversation.tags?.first?.tagColor, "#ff0000")
    }

    // MARK: - Message Model

    func testMessageDecoding() throws {
        let json = """
        {
            "message_id": "msg_123",
            "conversation_id": "conv_456",
            "sender_type": "user",
            "sender_id": "user_789",
            "message": "Hello, this is a test message",
            "message_type": "text",
            "is_internal_note": false,
            "created_at": 1702734000000
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(Message.self, from: json)

        XCTAssertEqual(message.id, "msg_123")
        XCTAssertEqual(message.conversationID, "conv_456")
        XCTAssertEqual(message.senderType, .user)
        XCTAssertEqual(message.senderID, "user_789")
        XCTAssertEqual(message.message, "Hello, this is a test message")
        XCTAssertEqual(message.messageType, "text")
        XCTAssertFalse(message.isInternalNote)
    }

    func testMessageWithAdminSender() throws {
        let json = """
        {
            "message_id": "msg_admin",
            "conversation_id": "conv_456",
            "sender_type": "admin",
            "sender_id": "admin_001",
            "sender_name": "Support Agent",
            "sender_avatar_url": "https://example.com/avatar.png",
            "message": "How can I help you?",
            "message_type": "text",
            "is_internal_note": false,
            "created_at": 1702734000000
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(Message.self, from: json)

        XCTAssertEqual(message.senderType, .admin)
        XCTAssertEqual(message.senderName, "Support Agent")
        XCTAssertEqual(message.senderAvatarUrl, "https://example.com/avatar.png")
    }

    func testMessageInternalNote() throws {
        let json = """
        {
            "message_id": "msg_note",
            "conversation_id": "conv_456",
            "sender_type": "admin",
            "message": "Internal note for team",
            "message_type": "text",
            "is_internal_note": true,
            "created_at": 1702734000000
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(Message.self, from: json)

        XCTAssertTrue(message.isInternalNote)
    }

    // MARK: - Link Token Response

    func testLinkTokenResponseDecoding() throws {
        let json = """
        {
            "link_token": "lt_abc123xyz",
            "expires_at": 1702737600000,
            "expires_in": 3600,
            "has_existing_group": false
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkTokenResponse.self, from: json)

        XCTAssertEqual(response.linkToken, "lt_abc123xyz")
        XCTAssertEqual(response.expiresAt, 1702737600000)
        XCTAssertEqual(response.expiresIn, 3600)
        XCTAssertFalse(response.hasExistingGroup)
    }

    func testLinkTokenResponseWithExistingGroup() throws {
        let json = """
        {
            "link_token": "lt_existing",
            "expires_at": 1702737600000,
            "expires_in": 3600,
            "has_existing_group": true
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkTokenResponse.self, from: json)

        XCTAssertTrue(response.hasExistingGroup)
    }

    // MARK: - Link Confirm Response

    func testLinkConfirmResponseDecoding() throws {
        let json = """
        {
            "success": true,
            "group_id": "group_456",
            "message": "Device linked successfully"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkConfirmResponse.self, from: json)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.groupId, "group_456")
        XCTAssertEqual(response.message, "Device linked successfully")
    }

    // MARK: - Link Status Response

    func testLinkStatusResponsePending() throws {
        let json = """
        {
            "status": "pending",
            "link_token": "lt_pending",
            "expires_at": 1702737600000
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkStatusResponse.self, from: json)

        XCTAssertEqual(response.status, .pending)
        XCTAssertNil(response.groupId)
    }

    func testLinkStatusResponseConfirmed() throws {
        let json = """
        {
            "status": "confirmed",
            "link_token": "lt_confirmed",
            "group_id": "group_123",
            "target_device_name": "iPhone 15",
            "confirmed_at": 1702734500000
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkStatusResponse.self, from: json)

        XCTAssertEqual(response.status, .confirmed)
        XCTAssertEqual(response.groupId, "group_123")
        XCTAssertEqual(response.targetDeviceName, "iPhone 15")
    }

    func testLinkStatusResponseExpired() throws {
        let json = """
        {
            "status": "expired"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkStatusResponse.self, from: json)

        XCTAssertEqual(response.status, .expired)
    }

    // MARK: - Linked Devices Response

    func testLinkedDevicesResponseDecoding() throws {
        let json = """
        {
            "linked": true,
            "group_id": "group_main",
            "devices": [
                {
                    "device_id": "device_1",
                    "device_name": "iPhone 15",
                    "joined_at": 1702734000000,
                    "is_primary": true,
                    "is_current": true
                },
                {
                    "device_id": "device_2",
                    "device_name": "iPad Pro",
                    "joined_at": 1702735000000,
                    "is_primary": false,
                    "is_current": false
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkedDevicesResponse.self, from: json)

        XCTAssertTrue(response.linked)
        XCTAssertEqual(response.groupId, "group_main")
        XCTAssertEqual(response.devices.count, 2)
        XCTAssertTrue(response.devices[0].isCurrent)
        XCTAssertTrue(response.devices[0].isPrimary)
        XCTAssertFalse(response.devices[1].isCurrent)
        XCTAssertFalse(response.devices[1].isPrimary)
    }

    func testLinkedDevicesResponseNotLinked() throws {
        let json = """
        {
            "linked": false,
            "devices": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkedDevicesResponse.self, from: json)

        XCTAssertFalse(response.linked)
        XCTAssertNil(response.groupId)
        XCTAssertTrue(response.devices.isEmpty)
    }

    // MARK: - Conversation Categories

    func testAllConversationCategoriesDecodable() throws {
        let categories = ["bug", "feature", "question", "feedback", "other"]

        for category in categories {
            let json = """
            {
                "conversation_id": "conv_\(category)",
                "category": "\(category)",
                "status": "open",
                "created_at": 1702734000000
            }
            """.data(using: .utf8)!

            let conversation = try JSONDecoder().decode(Conversation.self, from: json)
            XCTAssertEqual(conversation.category?.rawValue, category)
        }
    }

    // MARK: - Conversation Statuses

    func testAllConversationStatusesDecodable() throws {
        let statuses = ["open", "in_progress", "waiting_user", "waiting_admin", "resolved", "closed"]

        for status in statuses {
            let json = """
            {
                "conversation_id": "conv_\(status)",
                "status": "\(status)",
                "created_at": 1702734000000
            }
            """.data(using: .utf8)!

            let conversation = try JSONDecoder().decode(Conversation.self, from: json)
            XCTAssertEqual(conversation.status.rawValue, status)
        }
    }

    // MARK: - Conversation Priorities

    func testAllConversationPrioritiesDecodable() throws {
        let priorities = ["low", "normal", "high", "urgent"]

        for priority in priorities {
            let json = """
            {
                "conversation_id": "conv_\(priority)",
                "status": "open",
                "priority": "\(priority)",
                "created_at": 1702734000000
            }
            """.data(using: .utf8)!

            let conversation = try JSONDecoder().decode(Conversation.self, from: json)
            XCTAssertEqual(conversation.priority?.rawValue, priority)
        }
    }

    // MARK: - Sender Types

    func testAllSenderTypesDecodable() throws {
        let senderTypes = ["user", "admin", "system"]

        for senderType in senderTypes {
            let json = """
            {
                "message_id": "msg_\(senderType)",
                "conversation_id": "conv_123",
                "sender_type": "\(senderType)",
                "message": "Test",
                "message_type": "text",
                "is_internal_note": false,
                "created_at": 1702734000000
            }
            """.data(using: .utf8)!

            let message = try JSONDecoder().decode(Message.self, from: json)
            XCTAssertEqual(message.senderType.rawValue, senderType)
        }
    }

    // MARK: - Link Token Statuses

    func testAllLinkTokenStatusesDecodable() throws {
        let statuses = ["pending", "confirmed", "expired"]

        for status in statuses {
            let json = """
            {
                "status": "\(status)"
            }
            """.data(using: .utf8)!

            let response = try JSONDecoder().decode(LinkStatusResponse.self, from: json)
            XCTAssertEqual(response.status.rawValue, status)
        }
    }
}
