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
    public let userName: String?
    public let deviceID: String?
    public let title: String?
    public let category: ConversationCategory?
    public let status: ConversationStatus
    public let priority: ConversationPriority?
    public let assignedAdminID: String?
    public let appId: String?
    public let appName: String?
    public let messageCount: Int?
    public let unreadCount: Int?
    public let messages: [Message]?
    public let tags: [Tag]?
    public let createdAt: Int64
    public let updatedAt: Int64?

    public init(
        id: String,
        customerID: String? = nil,
        userID: String? = nil,
        userName: String? = nil,
        deviceID: String? = nil,
        title: String? = nil,
        category: ConversationCategory? = nil,
        status: ConversationStatus,
        priority: ConversationPriority? = nil,
        assignedAdminID: String? = nil,
        appId: String? = nil,
        messageCount: Int? = nil,
        unreadCount: Int? = nil,
        messages: [Message]? = nil,
        tags: [Tag]? = nil,
        createdAt: Int64,
        updatedAt: Int64? = nil
    ) {
        self.id = id
        self.customerID = customerID
        self.userID = userID
        self.userName = userName
        self.deviceID = deviceID
        self.title = title
        self.category = category
        self.status = status
        self.priority = priority
        self.assignedAdminID = assignedAdminID
        self.appId = appId
        self.appName = nil  // Deprecated, kept for API backward compatibility
        self.messageCount = messageCount
        self.unreadCount = unreadCount
        self.messages = messages
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id = "conversation_id"
        case customerID = "customer_id"
        case userID = "user_id"
        case userName = "user_name"
        case deviceID = "device_id"
        case title
        case category
        case status
        case priority
        case assignedAdminID = "assigned_admin_id"
        case appId = "app_id"
        case appName = "app_name"
        case messageCount = "message_count"
        case unreadCount = "unread_count"
        case messages
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Whether this conversation has unread messages
    public var hasUnread: Bool {
        (unreadCount ?? 0) > 0
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

// MARK: - Device Linking

/// Response from initiating a device link token
public struct LinkTokenResponse: Codable {
    /// Token to encode in QR code
    public let linkToken: String
    /// When the token expires (Unix timestamp in ms)
    public let expiresAt: Int64
    /// Seconds until expiration
    public let expiresIn: Int
    /// Whether this device already has linked devices
    public let hasExistingGroup: Bool

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
        case hasExistingGroup = "has_existing_group"
    }

    public var expirationDate: Date {
        Date(timeIntervalSince1970: TimeInterval(expiresAt) / 1000)
    }
}

/// Response from confirming a device link
public struct LinkConfirmResponse: Codable {
    public let success: Bool
    public let groupId: String
    public let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case groupId = "group_id"
        case message
    }
}

/// Status of a device link token
public enum LinkTokenStatus: String, Codable {
    case pending
    case confirmed
    case expired
}

/// Response from checking link token status
public struct LinkStatusResponse: Codable {
    public let status: LinkTokenStatus
    public let linkToken: String?
    public let groupId: String?
    public let targetDeviceName: String?
    public let confirmedAt: Int64?
    public let expiresAt: Int64?

    enum CodingKeys: String, CodingKey {
        case status
        case linkToken = "link_token"
        case groupId = "group_id"
        case targetDeviceName = "target_device_name"
        case confirmedAt = "confirmed_at"
        case expiresAt = "expires_at"
    }
}

/// A device linked to the current device's group
public struct LinkedDevice: Codable, Identifiable {
    public let deviceId: String
    public let deviceName: String
    public let joinedAt: Int64
    public let isPrimary: Bool
    public let isCurrent: Bool

    public var id: String { deviceId }

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceName = "device_name"
        case joinedAt = "joined_at"
        case isPrimary = "is_primary"
        case isCurrent = "is_current"
    }

    public var joinedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(joinedAt) / 1000)
    }
}

/// Response from listing linked devices
public struct LinkedDevicesResponse: Codable {
    /// Whether this device is linked to any group
    public let linked: Bool
    /// Group ID (if linked)
    public let groupId: String?
    /// All devices in the group
    public let devices: [LinkedDevice]

    enum CodingKeys: String, CodingKey {
        case linked
        case groupId = "group_id"
        case devices
    }
}

/// Response from unlinking a device
internal struct UnlinkDeviceResponse: Codable {
    let success: Bool
    let message: String
}
