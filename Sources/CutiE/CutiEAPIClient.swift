import Foundation
import CommonCrypto
import Security

#if canImport(UIKit)
import UIKit
#endif

/// Internal API client for CutiE
internal class CutiEAPIClient {

    internal let configuration: CutiEConfiguration
    private let session: URLSession

    /// Device token for authentication (stored in Keychain)
    private var deviceToken: String? {
        get { getDeviceTokenFromKeychain() }
        set { saveDeviceTokenToKeychain(newValue) }
    }

    /// Whether we've attempted to register for a device token this session
    private var hasAttemptedTokenRegistration = false

    init(configuration: CutiEConfiguration) {
        self.configuration = configuration

        // Set delegateQueue to .main for SwiftUI compatibility
        // Use certificate pinning for secure API communication
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = CutiECertificatePinning.shared.createPinnedSession(configuration: config)
    }

    // MARK: - Keychain Storage for Device Token

    private let deviceTokenKeychainKey = "com.cutie.deviceToken"

    private func getDeviceTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: deviceTokenKeychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    private func saveDeviceTokenToKeychain(_ token: String?) {
        // First, delete any existing token
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: deviceTokenKeychainKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // If token is nil, we're done (just wanted to delete)
        guard let token = token, let data = token.data(using: .utf8) else { return }

        // Add the new token
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: deviceTokenKeychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(addQuery as CFDictionary, nil)
    }

    // MARK: - Device Token Registration

    /// Register device and get a device token for future API calls
    private func registerDeviceToken(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(configuration.apiURL)/v1/device/register") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(CutiE.sdkVersion, forHTTPHeaderField: "X-CutiE-SDK-Version")
        request.setValue(configuration.appId, forHTTPHeaderField: "X-App-ID")
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Device-ID")
        // Include API key if available (deprecated, for backwards compatibility)
        if let apiKey = configuration.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        // Include device info
        var body: [String: Any] = [:]
        if let appVersion = configuration.appVersion {
            body["app_version"] = appVersion
        }
        body["app_id"] = configuration.appId
        #if os(iOS)
        body["os_version"] = UIDevice.current.systemVersion
        body["device_model"] = UIDevice.current.model
        #endif

        if !body.isEmpty {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300,
                  let data = data else {
                completion(nil)
                return
            }

            // Parse response
            struct RegisterResponse: Decodable {
                let deviceToken: String
                let tokenId: String
                let isNew: Bool
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(RegisterResponse.self, from: data)

                // Save to keychain
                self?.deviceToken = response.deviceToken
                completion(response.deviceToken)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }

    // MARK: - Conversations

    func createConversation(
        category: ConversationCategory,
        message: String,
        title: String?,
        completion: @escaping (Result<Conversation, CutiEError>) -> Void
    ) {
        let endpoint = "/v1/conversations"

        var body: [String: Any] = [
            "category": category.rawValue,
            "initial_message": message
        ]

        body["app_id"] = configuration.appId

        if let title = title {
            body["title"] = title
        }

        if let userID = configuration.userID {
            body["user_id"] = userID
        }

        if let userName = configuration.userName {
            body["user_name"] = userName
        }

        // Include device context fields based on configuration.
        // For backward compatibility, conversations always send os_version and device_model
        // on iOS (existing behavior since SDK 1.0). app_version is sent when configured
        // via setAppMetadata(). The deviceContext config adds NEW fields like language/country.
        if let appVersion = configuration.appVersion {
            body["app_version"] = appVersion
        }

        #if os(iOS)
        body["os_version"] = UIDevice.current.systemVersion
        body["device_model"] = UIDevice.current.model
        #endif

        // Add configured device context fields (language, country, etc.)
        for (key, value) in configuration.deviceContextPayload() {
            body[key] = value
        }

        request(endpoint: endpoint, method: "POST", body: body) { (result: Result<CreateConversationResponse, CutiEError>) in
            switch result {
            case .success(let response):
                // Convert CreateConversationResponse to minimal Conversation object
                let conversation = Conversation(
                    id: response.conversationId,
                    customerID: nil,
                    userID: self.configuration.userID,
                    deviceID: self.configuration.deviceID,
                    title: title,
                    category: category,
                    status: response.conversationStatus,
                    priority: nil,
                    assignedAdminID: nil,
                    appId: self.configuration.appId,
                    messageCount: nil,
                    messages: nil,
                    tags: nil,
                    createdAt: response.createdAtInt64,
                    updatedAt: nil
                )
                completion(.success(conversation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Simplified version of createConversation that returns only the conversation ID
    func createConversationSimple(
        category: ConversationCategory,
        message: String,
        title: String?,
        completion: @escaping (Result<String, CutiEError>) -> Void
    ) {
        createConversation(category: category, message: message, title: title) { result in
            switch result {
            case .success(let conversation):
                completion(.success(conversation.id))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func listConversations(completion: @escaping (Result<[Conversation], CutiEError>) -> Void) {
        let endpoint = "/v1/conversations"

        request(endpoint: endpoint, method: "GET") { (result: Result<ConversationsListResponse, CutiEError>) in
            switch result {
            case .success(let response):
                completion(.success(response.conversations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Get unread message count
    func getUnreadCount(completion: @escaping (Result<Int, CutiEError>) -> Void) {
        let endpoint = "/v1/conversations?limit=1"  // Minimal query just to get unread count

        request(endpoint: endpoint, method: "GET") { (result: Result<ConversationsListResponse, CutiEError>) in
            switch result {
            case .success(let response):
                completion(.success(response.totalUnread ?? 0))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getConversation(_ conversationID: String, completion: @escaping (Result<Conversation, CutiEError>) -> Void) {
        let endpoint = "/v1/conversations/\(conversationID)"
        request(endpoint: endpoint, method: "GET", completion: completion)
    }

    /// Mark all messages in a conversation as read
    func markAllMessagesRead(_ conversationID: String, completion: @escaping (Result<Void, CutiEError>) -> Void) {
        let endpoint = "/v1/conversations/\(conversationID)/messages/mark-all-read"
        request(endpoint: endpoint, method: "POST") { (result: Result<EmptyResponse, CutiEError>) in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func sendMessage(
        _ message: String,
        in conversationID: String,
        completion: @escaping (Result<Message, CutiEError>) -> Void
    ) {
        let endpoint = "/v1/conversations/\(conversationID)/messages"
        var body: [String: Any] = ["message": message]

        if let userName = configuration.userName {
            body["user_name"] = userName
        }

        request(endpoint: endpoint, method: "POST", body: body, completion: completion)
    }

    // MARK: - Async/Await Wrappers (iOS 15+)

    @available(iOS 15.0, macOS 12.0, *)
    func getConversations() async throws -> [Conversation] {
        try await withCheckedThrowingContinuation { continuation in
            listConversations { result in
                switch result {
                case .success(let conversations):
                    continuation.resume(returning: conversations)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    func getConversation(id: String) async throws -> Conversation {
        try await withCheckedThrowingContinuation { continuation in
            getConversation(id) { result in
                switch result {
                case .success(let conversation):
                    continuation.resume(returning: conversation)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    func sendMessage(conversationId: String, message: String) async throws -> Message {
        try await withCheckedThrowingContinuation { continuation in
            sendMessage(message, in: conversationId) { result in
                switch result {
                case .success(let message):
                    continuation.resume(returning: message)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    func markAllMessagesRead(conversationId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            markAllMessagesRead(conversationId) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Push Notifications

    func registerPushToken(_ token: String, completion: @escaping (Result<Void, CutiEError>) -> Void) {
        let endpoint = "/v1/notifications/register"

        var body: [String: Any] = [
            "platform": "ios",
            "push_token": token
        ]

        // Send bundle_id so backend can link token to the correct app
        if let bundleId = Bundle.main.bundleIdentifier {
            body["bundle_id"] = bundleId
        }

        if let userID = configuration.userID {
            body["user_id"] = userID
        }

        if let appVersion = configuration.appVersion {
            body["app_version"] = appVersion
        }

        #if os(iOS)
        body["os_version"] = UIDevice.current.systemVersion
        body["device_model"] = UIDevice.current.model
        #endif

        request(endpoint: endpoint, method: "POST", body: body) { (result: Result<EmptyResponse, CutiEError>) in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func unregisterPushToken(completion: @escaping (Result<Void, CutiEError>) -> Void) {
        let endpoint = "/v1/notifications/unregister"
        let body: [String: Any] = ["platform": "ios"]

        request(endpoint: endpoint, method: "DELETE", body: body) { (result: Result<EmptyResponse, CutiEError>) in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Device Linking

    /// Initiate device linking - generates a token to encode in a QR code
    /// The scanning device will use this token to link to the same inbox
    func initiateLinkToken(completion: @escaping (Result<LinkTokenResponse, CutiEError>) -> Void) {
        let endpoint = "/v1/sdk/link/initiate"
        request(endpoint: endpoint, method: "POST", completion: completion)
    }

    /// Confirm device link after scanning a QR code
    /// - Parameters:
    ///   - linkToken: The token from the QR code
    ///   - deviceName: Optional name for this device (shown in linked devices list)
    func confirmLink(token linkToken: String, deviceName: String? = nil, completion: @escaping (Result<LinkConfirmResponse, CutiEError>) -> Void) {
        let endpoint = "/v1/sdk/link/confirm"
        var body: [String: Any] = ["link_token": linkToken]
        if let deviceName = deviceName {
            body["device_name"] = deviceName
        }
        request(endpoint: endpoint, method: "POST", body: body, completion: completion)
    }

    /// Check the status of a link token (for polling after showing QR code)
    /// - Parameter linkToken: The token to check
    func checkLinkStatus(token linkToken: String, completion: @escaping (Result<LinkStatusResponse, CutiEError>) -> Void) {
        let endpoint = "/v1/sdk/link/status/\(linkToken)"
        request(endpoint: endpoint, method: "GET", completion: completion)
    }

    /// Get all devices linked to this device's group
    func getLinkedDevices(completion: @escaping (Result<LinkedDevicesResponse, CutiEError>) -> Void) {
        let endpoint = "/v1/sdk/link/devices"
        request(endpoint: endpoint, method: "GET", completion: completion)
    }

    /// Unlink a device from the group
    /// - Parameter deviceId: The device ID to unlink (can be current device or another in the group)
    func unlinkDevice(_ deviceId: String, completion: @escaping (Result<Void, CutiEError>) -> Void) {
        let endpoint = "/v1/sdk/link/devices/\(deviceId)"
        request(endpoint: endpoint, method: "DELETE") { (result: Result<UnlinkDeviceResponse, CutiEError>) in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Device Linking (Async/Await)

    @available(iOS 15.0, macOS 12.0, *)
    func initiateLinkToken() async throws -> LinkTokenResponse {
        try await withCheckedThrowingContinuation { continuation in
            initiateLinkToken { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    func confirmLink(token linkToken: String, deviceName: String? = nil) async throws -> LinkConfirmResponse {
        try await withCheckedThrowingContinuation { continuation in
            confirmLink(token: linkToken, deviceName: deviceName) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    func checkLinkStatus(token linkToken: String) async throws -> LinkStatusResponse {
        try await withCheckedThrowingContinuation { continuation in
            checkLinkStatus(token: linkToken) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    func getLinkedDevices() async throws -> LinkedDevicesResponse {
        try await withCheckedThrowingContinuation { continuation in
            getLinkedDevices { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    func unlinkDevice(_ deviceId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unlinkDevice(deviceId) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - App Attest

    /// Get a challenge for App Attest attestation
    @available(iOS 14.0, macOS 11.0, *)
    func getAttestChallenge() async throws -> AttestChallengeResponse {
        try await withCheckedThrowingContinuation { continuation in
            request(endpoint: "/v1/device/attest/challenge", method: "POST") { (result: Result<AttestChallengeResponse, CutiEError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Submit attestation to server
    @available(iOS 14.0, macOS 11.0, *)
    func submitAttestation(keyId: String, attestation: String) async throws {
        let body: [String: Any] = [
            "key_id": keyId,
            "attestation": attestation
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            request(endpoint: "/v1/device/attest", method: "POST", body: body) { (result: Result<AttestResponse, CutiEError>) in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Submit an assertion for verification
    @available(iOS 14.0, macOS 11.0, *)
    func submitAssertion(keyId: String, assertion: String, clientData: String) async throws {
        let body: [String: Any] = [
            "key_id": keyId,
            "assertion": assertion,
            "client_data": clientData
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            request(endpoint: "/v1/device/attest/assert", method: "POST", body: body) { (result: Result<EmptyResponse, CutiEError>) in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Get attestation status
    @available(iOS 14.0, macOS 11.0, *)
    func getAttestStatus() async throws -> AttestationStatus {
        try await withCheckedThrowingContinuation { continuation in
            request(endpoint: "/v1/device/attest/status", method: "GET") { (result: Result<AttestationStatus, CutiEError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Revoke attestation
    @available(iOS 14.0, macOS 11.0, *)
    func revokeAttestation() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            request(endpoint: "/v1/device/attest", method: "DELETE") { (result: Result<EmptyResponse, CutiEError>) in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Device Signature

    static func generateDeviceSignature(deviceID: String, timestamp: String, salt: String) -> String {
        let input = "\(deviceID):\(timestamp):\(salt)"
        guard let data = input.data(using: .utf8) else { return "" }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Generate device secret for API authentication
    internal func generateDeviceSecret() -> String {
        // The device secret is a hash of deviceID + salt
        // Salt should match the backend's DEVICE_SALT env var
        let salt = "cutie-device-salt-v1" // Default salt for SDK
        let input = "\(configuration.deviceID)\(salt)"
        guard let data = input.data(using: .utf8) else { return "" }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Activity Ping

    /// Send a fire-and-forget activity ping. Bypasses the normal request pipeline
    /// (no ensureDeviceToken, no response decoding). All errors are silently ignored.
    func sendActivityPing(hashedDeviceID: String) {
        guard let url = URL(string: "\(configuration.apiURL)/v1/activity/ping") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(CutiE.sdkVersion, forHTTPHeaderField: "X-CutiE-SDK-Version")
        request.setValue(configuration.appId, forHTTPHeaderField: "X-App-ID")
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Device-ID")
        if let token = getDeviceTokenFromKeychain() {
            request.setValue(token, forHTTPHeaderField: "X-Device-Token")
        }

        var body: [String: Any] = [
            "hashed_device_id": hashedDeviceID,
            "consent": true
        ]

        // Include configured device context fields
        for (key, value) in configuration.deviceContextPayload() {
            body[key] = value
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Fire-and-forget — ignore response and errors
        session.dataTask(with: request) { _, _, _ in }.resume()
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        completion: @escaping (Result<T, CutiEError>) -> Void
    ) {
        // Try to get or register device token first (if not already attempted this session)
        ensureDeviceToken { [weak self] in
            self?.performRequest(endpoint: endpoint, method: method, body: body, completion: completion)
        }
    }

    /// Ensure we have a device token (register if needed)
    private func ensureDeviceToken(completion: @escaping () -> Void) {
        // If we already have a token, proceed immediately
        if deviceToken != nil {
            completion()
            return
        }

        // If we've already tried to register this session, don't retry
        if hasAttemptedTokenRegistration {
            completion()
            return
        }

        // Try to register for a device token (async, but don't block the request)
        hasAttemptedTokenRegistration = true
        registerDeviceToken { _ in
            // Proceed regardless of success/failure
            // API key fallback will handle authentication
            completion()
        }
    }

    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        completion: @escaping (Result<T, CutiEError>) -> Void
    ) {
        guard let url = URL(string: "\(configuration.apiURL)\(endpoint)") else {
            completion(.failure(.invalidRequest))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(CutiE.sdkVersion, forHTTPHeaderField: "X-CutiE-SDK-Version")

        // Use device token if available (preferred)
        if let token = deviceToken {
            request.setValue(token, forHTTPHeaderField: "X-Device-Token")
        }
        // Always include App ID and device ID for authentication
        request.setValue(configuration.appId, forHTTPHeaderField: "X-App-ID")
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Device-ID")
        // Include API key if available (deprecated, for backwards compatibility)
        if let apiKey = configuration.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(.invalidRequest))
                return
            }
        }

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.networkError(NSError(domain: "CutiE", code: -1, userInfo: nil))))
                return
            }

            guard let data = data else {
                completion(.failure(.networkError(NSError(domain: "CutiE", code: -1, userInfo: nil))))
                return
            }

            // Handle HTTP errors
            if httpResponse.statusCode >= 400 {
                // If we get 401 with device token, it might be revoked - clear it and retry will use API key
                if httpResponse.statusCode == 401 && self?.deviceToken != nil {
                    self?.deviceToken = nil
                    self?.hasAttemptedTokenRegistration = false
                }

                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(.serverError(httpResponse.statusCode, errorResponse.error)))
                } else {
                    completion(.failure(.serverError(httpResponse.statusCode, "Unknown error")))
                }
                return
            }

            // Decode success response
            do {
                let decoder = JSONDecoder()
                // Note: Don't use .convertFromSnakeCase since models have explicit CodingKeys
                let result = try decoder.decode(T.self, from: data)
                completion(.success(result))
            } catch {
                #if DEBUG
                // Log decoding errors only in debug builds
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        NSLog("[CutiE] Missing key: \(key.stringValue) - \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        NSLog("[CutiE] Type mismatch for type: \(type) - \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        NSLog("[CutiE] Value not found for type: \(type) - \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        NSLog("[CutiE] Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        NSLog("[CutiE] Unknown decoding error: \(decodingError)")
                    }
                }
                #endif
                completion(.failure(.decodingError()))
            }
        }

        task.resume()
    }
}

// MARK: - Response Types

private struct ConversationsListResponse: Decodable {
    let conversations: [Conversation]
    let totalUnread: Int?

    enum CodingKeys: String, CodingKey {
        case conversations
        case totalUnread = "total_unread"
    }
}

private struct ErrorResponse: Decodable {
    let error: String
}

private struct EmptyResponse: Decodable {}
