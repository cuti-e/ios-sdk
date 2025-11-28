import Foundation
import CommonCrypto

#if canImport(UIKit)
import UIKit
#endif

/// Internal API client for CutiE
internal class CutiEAPIClient {

    internal let configuration: CutiEConfiguration
    private let session: URLSession

    init(configuration: CutiEConfiguration) {
        self.configuration = configuration

        // Set delegateQueue to .main for SwiftUI compatibility
        // Use certificate pinning for secure API communication
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = CutiECertificatePinning.shared.createPinnedSession(configuration: config)
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

        // Prefer app_id over app_name
        if let appId = configuration.appId {
            body["app_id"] = appId
        } else if let appName = configuration.appName {
            body["app_name"] = appName
        }

        if let title = title {
            body["title"] = title
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
                    appName: self.configuration.appName,
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

    func getConversation(_ conversationID: String, completion: @escaping (Result<Conversation, CutiEError>) -> Void) {
        let endpoint = "/v1/conversations/\(conversationID)"
        request(endpoint: endpoint, method: "GET", completion: completion)
    }

    func sendMessage(
        _ message: String,
        in conversationID: String,
        completion: @escaping (Result<Message, CutiEError>) -> Void
    ) {
        let endpoint = "/v1/conversations/\(conversationID)/messages"
        let body: [String: Any] = ["message": message]

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

    // MARK: - Push Notifications

    func registerPushToken(_ token: String, completion: @escaping (Result<Void, CutiEError>) -> Void) {
        let endpoint = "/v1/notifications/register"

        var body: [String: Any] = [
            "platform": "ios",
            "push_token": token
        ]

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

    // MARK: - Generic Request

    private func request<T: Decodable>(
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
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Device-ID")

        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(.invalidRequest))
                return
            }
        }

        let task = session.dataTask(with: request) { data, response, error in
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
                decoder.keyDecodingStrategy = .convertFromSnakeCase
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
}

private struct ErrorResponse: Decodable {
    let error: String
}

private struct EmptyResponse: Decodable {}
