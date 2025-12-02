import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Main Cuti-E SDK class
public class CutiE {

    /// Shared singleton instance
    public static let shared = CutiE()

    /// Configuration
    internal var configuration: CutiEConfiguration?

    /// API client
    internal var apiClient: CutiEAPIClient?

    /// Subscription manager (iOS 15+)
    @available(iOS 15.0, macOS 12.0, *)
    public var subscriptionManager: CutiESubscriptionManager {
        return CutiESubscriptionManager.shared
    }

    /// Device ID (persistent across app launches)
    private var deviceID: String {
        let key = "com.cutie.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }

        let newID = "device_\(UUID().uuidString)"
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }

    private init() {
        // Private initializer for singleton pattern
    }

    /// Push notification manager for receiving notifications
    @available(iOS 10.0, macOS 10.14, *)
    public var pushNotifications: CutiEPushNotifications {
        return CutiEPushNotifications.shared
    }

    /// Configure CutiE with your API key and App ID
    /// - Parameters:
    ///   - apiKey: Your Cuti-E API key from the admin dashboard
    ///   - appId: Your App ID from the admin dashboard (created in Settings > Apps)
    ///   - apiURL: Optional custom API URL (defaults to production)
    public func configure(apiKey: String, appId: String, apiURL: String = "https://api.cuti-e.com") {
        self.configuration = CutiEConfiguration(
            apiKey: apiKey,
            apiURL: apiURL,
            deviceID: deviceID,
            appId: appId
        )

        self.apiClient = CutiEAPIClient(configuration: configuration!)

        // Notify push notification manager that SDK is configured
        if #available(iOS 10.0, macOS 10.14, *) {
            CutiEPushNotifications.shared.onSDKConfigured()
        }
    }

    /// Check if CutiE is configured
    public var isConfigured: Bool {
        return configuration != nil && apiClient != nil
    }

    /// Set user ID for tracking
    /// - Parameter userID: Unique identifier for the current user
    public func setUserID(_ userID: String?) {
        configuration?.userID = userID
    }

    /// Set user ID for tracking (alias for setUserID)
    /// - Parameter userId: Unique identifier for the current user
    public func setUserId(_ userId: String?) {
        setUserID(userId)
    }

    /// Set app metadata
    /// - Parameters:
    ///   - version: App version
    ///   - build: App build number
    public func setAppMetadata(version: String, build: String) {
        configuration?.appVersion = version
        configuration?.appBuild = build
    }

    // MARK: - Conversations

    /// Create a new conversation
    /// - Parameters:
    ///   - category: Conversation category (bug, feature, question, feedback, other)
    ///   - message: Initial message
    ///   - title: Optional conversation title
    ///   - completion: Completion handler with conversation ID
    public func createConversation(
        category: ConversationCategory,
        message: String,
        title: String? = nil,
        completion: @escaping (Result<String, CutiEError>) -> Void
    ) {
        guard let client = apiClient else {
            completion(.failure(.notConfigured))
            return
        }

        client.createConversationSimple(
            category: category,
            message: message,
            title: title,
            completion: completion
        )
    }

    // MARK: - Inbox (iOS 15+)

    /// Get all conversations for this device
    /// - Returns: Array of conversations
    @available(iOS 15.0, macOS 12.0, *)
    public func getConversations() async throws -> [Conversation] {
        guard let client = apiClient else {
            throw CutiEError.notConfigured
        }
        return try await client.getConversations()
    }

    /// Get a single conversation with messages
    /// - Parameter id: Conversation ID
    /// - Returns: Conversation with messages
    @available(iOS 15.0, macOS 12.0, *)
    public func getConversation(id: String) async throws -> Conversation {
        guard let client = apiClient else {
            throw CutiEError.notConfigured
        }
        return try await client.getConversation(id: id)
    }

    /// Send a message in a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - message: Message content
    /// - Returns: The sent message
    @available(iOS 15.0, macOS 12.0, *)
    public func sendMessage(conversationId: String, message: String) async throws -> Message {
        guard let client = apiClient else {
            throw CutiEError.notConfigured
        }
        return try await client.sendMessage(conversationId: conversationId, message: message)
    }

    /// Get the count of unread messages (admin replies not yet read)
    /// - Returns: Number of unread messages
    @available(iOS 15.0, macOS 12.0, *)
    public func getUnreadCount() async throws -> Int {
        guard let client = apiClient else {
            throw CutiEError.notConfigured
        }
        return try await withCheckedThrowingContinuation { continuation in
            client.getUnreadCount { result in
                switch result {
                case .success(let count):
                    continuation.resume(returning: count)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Push Notifications

    /// Register a push notification device token (hex string format)
    /// Call this from your AppDelegate after receiving the device token
    /// - Parameter deviceToken: The device token as a hex string
    @available(iOS 10.0, macOS 10.14, *)
    public func registerForPushNotifications(deviceToken: String) {
        pushNotifications.registerToken(deviceToken)
    }

    #if os(iOS)
    // MARK: - Inbox UI

    /// Present the inbox view modally
    /// - Parameter from: The view controller to present from (optional, will find topmost if nil)
    @available(iOS 15.0, *)
    public func showInbox(from viewController: UIViewController? = nil) {
        guard isConfigured else {
            NSLog("[CutiE] Cannot show inbox: SDK not configured")
            return
        }

        let inboxView = CutiEInboxView()
        let hostingController = UIHostingController(rootView: inboxView)
        hostingController.modalPresentationStyle = .pageSheet

        let presenter = viewController ?? Self.topViewController()
        presenter?.present(hostingController, animated: true)
    }

    /// Find the topmost view controller
    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              var topController = window.rootViewController else {
            return nil
        }

        while let presented = topController.presentedViewController {
            topController = presented
        }

        return topController
    }
    #endif
}

/// CutiE Configuration
public class CutiEConfiguration {
    public let apiKey: String
    public let apiURL: String
    public let deviceID: String
    public let appId: String
    public var userID: String?
    public var appVersion: String?
    public var appBuild: String?

    /// Initialize with App ID
    init(apiKey: String, apiURL: String, deviceID: String, appId: String) {
        self.apiKey = apiKey
        self.apiURL = apiURL
        self.deviceID = deviceID
        self.appId = appId
    }
}

/// CutiE Error types
public enum CutiEError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case networkError(Error)
    case serverError(Int, String)
    case decodingError(String? = nil)
    case invalidRequest

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "CutiE is not configured. Call CutiE.shared.configure() first."
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let details):
            if let details = details {
                return details
            }
            return "Failed to decode server response"
        case .invalidRequest:
            return "Invalid request"
        }
    }
}
