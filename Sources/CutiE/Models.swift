import Foundation

// MARK: - API Response Types

/// Response from creating a new conversation
internal struct CreateConversationResponse: Codable {
    let conversationId: String
    let status: String?
    let messageId: String?
    let createdAt: Int?

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case status
        case messageId = "message_id"
        case createdAt = "created_at"
    }

    /// Get status as ConversationStatus enum, defaulting to .open if invalid or missing
    var conversationStatus: ConversationStatus {
        guard let status = status,
              let enumValue = ConversationStatus(rawValue: status) else {
            return .open
        }
        return enumValue
    }

    /// Get createdAt as Int64, defaulting to current timestamp if missing
    var createdAtInt64: Int64 {
        if let createdAt = createdAt {
            return Int64(createdAt)
        }
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - Conversation

/// Represents a support conversation
public struct Conversation: Codable, Identifiable {
    public let id: String
    public let customerID: String?
    public let userID: String?
    public let deviceID: String?
    public let title: String?
    public let category: ConversationCategory?
    public let status: ConversationStatus
    public let priority: ConversationPriority?
    public let assignedAdminID: String?
    public let appId: String?
    public let appName: String?
    public let messageCount: Int?
    public let messages: [Message]?
    public let tags: [Tag]?
    public let createdAt: Int64
    public let updatedAt: Int64?

    public init(
        id: String,
        customerID: String? = nil,
        userID: String? = nil,
        deviceID: String? = nil,
        title: String? = nil,
        category: ConversationCategory? = nil,
        status: ConversationStatus,
        priority: ConversationPriority? = nil,
        assignedAdminID: String? = nil,
        appId: String? = nil,
        messageCount: Int? = nil,
        messages: [Message]? = nil,
        tags: [Tag]? = nil,
        createdAt: Int64,
        updatedAt: Int64? = nil
    ) {
        self.id = id
        self.customerID = customerID
        self.userID = userID
        self.deviceID = deviceID
        self.title = title
        self.category = category
        self.status = status
        self.priority = priority
        self.assignedAdminID = assignedAdminID
        self.appId = appId
        self.appName = nil  // Deprecated, kept for API backward compatibility
        self.messageCount = messageCount
        self.messages = messages
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id = "conversation_id"
        case customerID = "customer_id"
        case userID = "user_id"
        case deviceID = "device_id"
        case title
        case category
        case status
        case priority
        case assignedAdminID = "assigned_admin_id"
        case appId = "app_id"
        case appName = "app_name"
        case messageCount = "message_count"
        case messages
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000)
    }

    public var updatedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(updatedAt ?? createdAt) / 1000)
    }
}

// MARK: - Message

/// Represents a message in a conversation
public struct Message: Codable, Identifiable {
    public let id: String
    public let conversationID: String
    public let senderType: SenderType
    public let senderID: String?
    public let senderName: String?
    public let senderAvatarUrl: String?
    public let message: String
    public let messageType: String
    public let isInternalNote: Bool
    public let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id = "message_id"
        case conversationID = "conversation_id"
        case senderType = "sender_type"
        case senderID = "sender_id"
        case senderName = "sender_name"
        case senderAvatarUrl = "sender_avatar_url"
        case message
        case messageType = "message_type"
        case isInternalNote = "is_internal_note"
        case createdAt = "created_at"
    }

    public var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000)
    }

    public init(
        id: String,
        conversationID: String,
        senderType: SenderType,
        senderID: String? = nil,
        senderName: String? = nil,
        senderAvatarUrl: String? = nil,
        message: String,
        messageType: String = "text",
        isInternalNote: Bool = false,
        createdAt: Int64
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderType = senderType
        self.senderID = senderID
        self.senderName = senderName
        self.senderAvatarUrl = senderAvatarUrl
        self.message = message
        self.messageType = messageType
        self.isInternalNote = isInternalNote
        self.createdAt = createdAt
    }
}

/// Message sender type
public enum SenderType: String, Codable {
    case user
    case admin
    case system
}

// MARK: - Tag

/// Represents a conversation tag
public struct Tag: Codable, Identifiable {
    public let id: String
    public let conversationID: String
    public let tagName: String
    public let tagColor: String?

    enum CodingKeys: String, CodingKey {
        case id = "tag_id"
        case conversationID = "conversation_id"
        case tagName = "tag_name"
        case tagColor = "tag_color"
    }
}

// MARK: - Enums

/// Conversation category
public enum ConversationCategory: String, Codable, CaseIterable {
    case bug
    case feature
    case question
    case feedback
    case other

    public var displayName: String {
        switch self {
        case .bug: return "Bug Report"
        case .feature: return "Feature Request"
        case .question: return "Question"
        case .feedback: return "Feedback"
        case .other: return "Other"
        }
    }

    /// SF Symbol name for professional icons
    public var sfSymbol: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .feature: return "sparkles"
        case .question: return "questionmark.circle.fill"
        case .feedback: return "bubble.left.and.bubble.right.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    public var color: String {
        switch self {
        case .bug: return "red"
        case .feature: return "purple"
        case .question: return "blue"
        case .feedback: return "green"
        case .other: return "gray"
        }
    }
}

/// Conversation status
public enum ConversationStatus: String, Codable, CaseIterable {
    case open
    case in_progress
    case waiting_user
    case waiting_admin
    case resolved
    case closed

    public var displayName: String {
        switch self {
        case .open: return "Open"
        case .in_progress: return "In Progress"
        case .waiting_user: return "Waiting for User"
        case .waiting_admin: return "Waiting for Admin"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }

    public var color: String {
        switch self {
        case .open: return "blue"
        case .in_progress: return "orange"
        case .waiting_user: return "yellow"
        case .waiting_admin: return "red"
        case .resolved: return "green"
        case .closed: return "gray"
        }
    }
}

/// Conversation priority
public enum ConversationPriority: String, Codable, CaseIterable {
    case low
    case normal
    case high
    case urgent

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    public var color: String {
        switch self {
        case .low: return "gray"
        case .normal: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}
