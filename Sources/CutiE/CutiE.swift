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

    /// App Attest manager for cryptographic device verification (iOS 14+)
    @available(iOS 14.0, macOS 11.0, *)
    public var appAttest: CutiEAppAttest {
        return CutiEAppAttest.shared
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

    /// Configure CutiE with your App ID (API key no longer required)
    /// - Parameters:
    ///   - appId: Your App ID from the admin dashboard (created in Settings > Apps)
    ///   - apiURL: Optional custom API URL (defaults to production)
    ///   - useAppAttest: Enable Apple App Attest for enhanced security (iOS 14+). When enabled, requests are cryptographically signed by the Secure Enclave. Automatically falls back on unsupported devices.
    public func configure(appId: String, apiURL: String = "https://api.cuti-e.com", useAppAttest: Bool = false) {
        // Enforce HTTPS for security and validate URL format
        guard let url = URL(string: apiURL), url.scheme?.lowercased() == "https" else {
            NSLog("[CutiE] ERROR: apiURL must be a valid HTTPS URL. Configuration rejected.")
            return
        }

        self.configuration = CutiEConfiguration(
            apiKey: nil,
            apiURL: apiURL,
            deviceID: deviceID,
            appId: appId,
            useAppAttest: useAppAttest
        )

        self.apiClient = CutiEAPIClient(configuration: configuration!)

        // Notify push notification manager that SDK is configured
        if #available(iOS 10.0, macOS 10.14, *) {
            CutiEPushNotifications.shared.onSDKConfigured()
        }

        // Initialize App Attest if enabled
        if useAppAttest {
            if #available(iOS 14.0, macOS 11.0, *) {
                initializeAppAttest()
            } else {
                NSLog("[CutiE] App Attest requested but requires iOS 14+ (current device not supported)")
            }
        }
    }

    /// Initialize App Attest in the background
    @available(iOS 14.0, macOS 11.0, *)
    private func initializeAppAttest() {
        let appAttest = CutiEAppAttest.shared

        guard appAttest.isSupported else {
            NSLog("[CutiE] App Attest not supported on this device (simulator or older hardware)")
            return
        }

        // If already attested, we're good
        if appAttest.isAttested {
            NSLog("[CutiE] App Attest: Device already attested")
            return
        }

        // Perform attestation in background
        Task {
            do {
                guard let client = apiClient else { return }
                try await appAttest.performAttestation(apiClient: client)
                NSLog("[CutiE] App Attest: Initial attestation completed")
            } catch {
                NSLog("[CutiE] App Attest: Initial attestation failed (will retry): \(error.localizedDescription)")
            }
        }
    }

    /// Configure CutiE with API key and App ID (deprecated - API key no longer required)
    /// - Parameters:
    ///   - apiKey: Your Cuti-E API key (no longer required, kept for backwards compatibility)
    ///   - appId: Your App ID from the admin dashboard (created in Settings > Apps)
    ///   - apiURL: Optional custom API URL (defaults to production)
    @available(*, deprecated, message: "API key is no longer required. Use configure(appId:) instead.")
    public func configure(apiKey: String, appId: String, apiURL: String = "https://api.cuti-e.com") {
        // Ignore the API key, use new authentication
        configure(appId: appId, apiURL: apiURL)
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

    /// Set optional user name for feedback attribution
    /// - Parameter userName: Display name to show with feedback (e.g., "John D.")
    public func setUserName(_ userName: String?) {
        configuration?.userName = userName
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
    /// - Returns: Result indicating success or validation error
    @available(iOS 10.0, macOS 10.14, *)
    @discardableResult
    public func registerForPushNotifications(deviceToken: String) -> Result<Void, CutiEError> {
        return pushNotifications.registerToken(deviceToken)
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
    public let apiKey: String?
    public let apiURL: String
    public let deviceID: String
    public let appId: String
    public var userID: String?
    public var userName: String?
    public var appVersion: String?
    public var appBuild: String?

    /// Whether App Attest is enabled for enhanced security (iOS 14+)
    public let useAppAttest: Bool

    /// Initialize with App ID (API key optional for backwards compatibility)
    init(apiKey: String?, apiURL: String, deviceID: String, appId: String, useAppAttest: Bool = false) {
        self.apiKey = apiKey
        self.apiURL = apiURL
        self.deviceID = deviceID
        self.appId = appId
        self.useAppAttest = useAppAttest
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
    case invalidPushToken(String)

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
        case .invalidPushToken(let reason):
            return "Invalid push token: \(reason)"
        }
    }
}
