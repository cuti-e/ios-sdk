import Foundation

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

    /// Configure CutiE with your API key (legacy method with appName)
    /// - Parameters:
    ///   - apiKey: Your Cuti-E API key from the admin dashboard
    ///   - appName: Name of your app (deprecated, use appId instead)
    ///   - apiURL: Optional custom API URL (defaults to production)
    @available(*, deprecated, message: "Use configure(apiKey:appId:apiURL:) instead. Create an App in the admin dashboard to get an App ID.")
    public func configure(apiKey: String, appName: String, apiURL: String = "https://api.cuti-e.com") {
        self.configuration = CutiEConfiguration(
            apiKey: apiKey,
            apiURL: apiURL,
            deviceID: deviceID,
            appName: appName
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
}

/// CutiE Configuration
public class CutiEConfiguration {
    public let apiKey: String
    public let apiURL: String
    public let deviceID: String
    public let appId: String?
    public let appName: String?
    public var userID: String?
    public var appVersion: String?
    public var appBuild: String?

    /// Initialize with App ID (preferred)
    init(apiKey: String, apiURL: String, deviceID: String, appId: String) {
        self.apiKey = apiKey
        self.apiURL = apiURL
        self.deviceID = deviceID
        self.appId = appId
        self.appName = nil
    }

    /// Initialize with App Name (legacy, deprecated)
    init(apiKey: String, apiURL: String, deviceID: String, appName: String) {
        self.apiKey = apiKey
        self.apiURL = apiURL
        self.deviceID = deviceID
        self.appId = nil
        self.appName = appName
    }

    /// Initialize for testing (no app identifier)
    init(apiKey: String, apiURL: String, deviceID: String) {
        self.apiKey = apiKey
        self.apiURL = apiURL
        self.deviceID = deviceID
        self.appId = nil
        self.appName = nil
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
