import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Delegate protocol for handling CutiE push notification events
@available(iOS 10.0, macOS 10.14, *)
public protocol CutiEPushNotificationDelegate: AnyObject {
    /// Called when a new message notification is received
    /// - Parameters:
    ///   - conversationId: The conversation ID that received a new message
    ///   - messagePreview: Preview of the message content
    func cutiEDidReceiveMessage(conversationId: String, messagePreview: String?)

    /// Called when the user taps on a CutiE notification
    /// - Parameter conversationId: The conversation ID to open
    func cutiEShouldOpenConversation(conversationId: String)
}

/// Extension with optional default implementations
@available(iOS 10.0, macOS 10.14, *)
public extension CutiEPushNotificationDelegate {
    func cutiEDidReceiveMessage(conversationId: String, messagePreview: String?) {}
    func cutiEShouldOpenConversation(conversationId: String) {}
}

/// Push notification manager for CutiE SDK
/// Handles device token registration and notification handling
@available(iOS 10.0, macOS 10.14, *)
public class CutiEPushNotifications: NSObject {

    /// Shared singleton instance
    public static let shared = CutiEPushNotifications()

    /// Delegate for push notification events
    public weak var delegate: CutiEPushNotificationDelegate?

    /// Whether push notifications are enabled
    public private(set) var isEnabled: Bool = false

    /// Current device token (hex string)
    private var deviceToken: String?

    /// Whether token has been registered with backend
    private var isTokenRegistered: Bool = false

    private override init() {
        super.init()
    }

    // MARK: - Permission Request

    #if canImport(UserNotifications)
    /// Request push notification permissions from the user
    /// - Parameter completion: Callback with granted status
    public func requestPermission(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    completion(granted)
                    return
                }

                self.isEnabled = granted

                if let error = error {
                    NSLog("[CutiE] Push permission error: \(error.localizedDescription)")
                }

                if granted {
                    NSLog("[CutiE] Push notification permission granted")
                    #if canImport(UIKit) && os(iOS)
                    self.registerForRemoteNotificationsInternal()
                    #endif
                } else {
                    NSLog("[CutiE] Push notification permission denied")
                }

                completion(granted)
            }
        }
    }

    /// Request permission using async/await (iOS 15+)
    @available(iOS 15.0, macOS 12.0, *)
    public func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            requestPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Check current notification authorization status
    public func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isEnabled = settings.authorizationStatus == .authorized
                completion(settings.authorizationStatus)
            }
        }
    }
    #endif

    // MARK: - Device Token Registration

    #if canImport(UIKit) && os(iOS)
    /// Register for remote notifications with APNs
    /// Call this after permission is granted
    public func registerForRemoteNotifications() {
        registerForRemoteNotificationsInternal()
    }

    private func registerForRemoteNotificationsInternal() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            NSLog("[CutiE] Requested remote notification registration")
        }
    }
    #endif

    /// Call this from your AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
    /// - Parameter deviceToken: The device token data from APNs
    public func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        let token = tokenParts.joined()
        registerToken(token)
    }

    /// Register a device token (hex string format) with the CutiE backend
    /// - Parameter token: The device token as a hex string
    /// - Returns: Result indicating success or validation error
    @discardableResult
    public func registerToken(_ token: String) -> Result<Void, CutiEError> {
        // Validate token before storing/registering
        if let error = validatePushToken(token) {
            NSLog("[CutiE] Invalid push token: \(error.localizedDescription)")
            return .failure(error)
        }

        self.deviceToken = token
        NSLog("[CutiE] Received device token: \(token.prefix(16))...")

        // Register with backend
        registerTokenWithBackend()
        return .success(())
    }

    /// Validate a push notification token
    /// - Parameter token: The token to validate
    /// - Returns: Error if invalid, nil if valid
    public func validatePushToken(_ token: String) -> CutiEError? {
        // Check for empty token
        guard !token.isEmpty else {
            return .invalidPushToken("Token cannot be empty")
        }

        // Check minimum length (APNs tokens are typically 64 hex chars = 32 bytes)
        guard token.count >= 32 else {
            return .invalidPushToken("Token too short (minimum 32 characters)")
        }

        // Check maximum length (allow for future expansion, but reject absurdly long values)
        guard token.count <= 200 else {
            return .invalidPushToken("Token too long (maximum 200 characters)")
        }

        // Validate hex format (only 0-9, a-f, A-F allowed)
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard token.unicodeScalars.allSatisfy({ hexCharacterSet.contains($0) }) else {
            return .invalidPushToken("Token must contain only hexadecimal characters (0-9, a-f)")
        }

        return nil
    }

    /// Call this from your AppDelegate's `application(_:didFailToRegisterForRemoteNotificationsWithError:)`
    /// - Parameter error: The registration error
    public func didFailToRegisterForRemoteNotifications(withError error: Error) {
        NSLog("[CutiE] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    /// Register the device token with the CutiE backend
    private func registerTokenWithBackend() {
        guard let token = deviceToken else {
            NSLog("[CutiE] No device token to register")
            return
        }

        guard let client = CutiE.shared.apiClient else {
            NSLog("[CutiE] SDK not configured - token will be registered when SDK is configured")
            return
        }

        client.registerPushToken(token) { [weak self] result in
            switch result {
            case .success:
                self?.isTokenRegistered = true
                NSLog("[CutiE] Push token registered with backend")
            case .failure(let error):
                NSLog("[CutiE] Failed to register push token: \(error.localizedDescription)")
            }
        }
    }

    /// Unregister push token (call on user logout if applicable)
    public func unregisterToken(completion: ((Result<Void, CutiEError>) -> Void)? = nil) {
        guard let client = CutiE.shared.apiClient else {
            completion?(.failure(.notConfigured))
            return
        }

        client.unregisterPushToken { [weak self] result in
            switch result {
            case .success:
                self?.isTokenRegistered = false
                self?.deviceToken = nil
                NSLog("[CutiE] Push token unregistered")
                completion?(.success(()))
            case .failure(let error):
                NSLog("[CutiE] Failed to unregister push token: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }

    // MARK: - Badge Management

    /// Clear the app icon badge count
    /// Call this when your app becomes active to reset the badge
    ///
    /// Example usage in your App struct:
    /// ```swift
    /// @Environment(\.scenePhase) private var scenePhase
    ///
    /// var body: some Scene {
    ///     WindowGroup {
    ///         ContentView()
    ///             .onChange(of: scenePhase) { newPhase in
    ///                 if newPhase == .active {
    ///                     CutiEPushNotifications.shared.clearBadgeCount()
    ///                 }
    ///             }
    ///     }
    /// }
    /// ```
    #if canImport(UserNotifications)
    public func clearBadgeCount() {
        if #available(iOS 16.0, macOS 13.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    NSLog("[CutiE] Failed to clear badge: \(error.localizedDescription)")
                } else {
                    NSLog("[CutiE] Badge count cleared")
                }
            }
        } else {
            // Fallback for older iOS versions
            #if canImport(UIKit) && os(iOS)
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
                NSLog("[CutiE] Badge count cleared (legacy)")
            }
            #endif
        }
    }
    #endif

    // MARK: - Notification Handling

    /// Check if a notification is from CutiE
    /// - Parameter userInfo: The notification payload
    /// - Returns: True if this is a CutiE notification
    public func isCutiENotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        return userInfo["conversation_id"] != nil || userInfo["cutie"] != nil
    }

    /// Handle a received notification
    /// Call this from your notification handling code
    /// - Parameter userInfo: The notification payload
    /// - Returns: True if the notification was handled by CutiE
    @discardableResult
    public func handleNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard isCutiENotification(userInfo) else {
            return false
        }

        let conversationId = userInfo["conversation_id"] as? String
        let messagePreview = (userInfo["aps"] as? [String: Any])?["alert"] as? String
            ?? (((userInfo["aps"] as? [String: Any])?["alert"] as? [String: Any])?["body"] as? String)

        if let conversationId = conversationId {
            NSLog("[CutiE] Received notification for conversation: \(conversationId)")
            delegate?.cutiEDidReceiveMessage(conversationId: conversationId, messagePreview: messagePreview)
        }

        return true
    }

    /// Handle notification tap/action
    /// Call this from your `userNotificationCenter(_:didReceive:withCompletionHandler:)`
    /// - Parameter userInfo: The notification payload
    /// - Returns: True if the notification was handled by CutiE
    @discardableResult
    public func handleNotificationTap(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard isCutiENotification(userInfo) else {
            return false
        }

        if let conversationId = userInfo["conversation_id"] as? String {
            NSLog("[CutiE] User tapped notification for conversation: \(conversationId)")
            delegate?.cutiEShouldOpenConversation(conversationId: conversationId)
        }

        return true
    }

    // MARK: - Internal

    /// Called when SDK is configured - register any pending token
    internal func onSDKConfigured() {
        if deviceToken != nil && !isTokenRegistered {
            registerTokenWithBackend()
        }
    }
}

// MARK: - SwiftUI Convenience

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
public extension View {
    /// Set up CutiE push notification handling
    /// - Parameter delegate: The delegate to receive notification events
    func cutiEPushNotifications(delegate: CutiEPushNotificationDelegate) -> some View {
        self.onAppear {
            CutiEPushNotifications.shared.delegate = delegate
        }
    }
}
#endif
