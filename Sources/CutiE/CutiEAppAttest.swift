import Foundation

#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// App Attest manager for cryptographic device verification
/// Uses Apple's DCAppAttestService to verify requests come from legitimate app installations
@available(iOS 14.0, macOS 11.0, *)
public class CutiEAppAttest {

    /// Shared singleton instance
    public static let shared = CutiEAppAttest()

    /// Key ID stored in Keychain
    private var keyId: String? {
        get { KeychainHelper.getString(forKey: "com.cutie.appAttest.keyId") }
        set {
            if let value = newValue {
                KeychainHelper.setString(value, forKey: "com.cutie.appAttest.keyId")
            } else {
                KeychainHelper.delete(forKey: "com.cutie.appAttest.keyId")
            }
        }
    }

    /// Whether the device has been attested
    public private(set) var isAttested: Bool = false

    /// Whether App Attest is supported on this device
    public var isSupported: Bool {
        #if canImport(DeviceCheck)
        return DCAppAttestService.shared.isSupported
        #else
        return false
        #endif
    }

    private init() {
        // Check if we have a stored key ID
        if keyId != nil {
            // Assume attested if key exists (will verify on first use)
            isAttested = true
        }
    }

    // MARK: - Attestation Flow

    /// Perform the full attestation flow
    /// 1. Generate key pair (if needed)
    /// 2. Get challenge from server
    /// 3. Attest key with Apple
    /// 4. Send attestation to server for verification
    /// - Parameter apiClient: API client for server communication
    internal func performAttestation(apiClient: CutiEAPIClient) async throws {
        #if canImport(DeviceCheck)
        guard isSupported else {
            throw AppAttestError.notSupported
        }

        let service = DCAppAttestService.shared

        // Step 1: Generate key if we don't have one
        let keyIdentifier: String
        if let existingKeyId = keyId {
            keyIdentifier = existingKeyId
        } else {
            keyIdentifier = try await service.generateKey()
            keyId = keyIdentifier
        }

        // Step 2: Get challenge from server
        let challengeResponse = try await apiClient.getAttestChallenge()
        let challenge = challengeResponse.challenge

        // Step 3: Create client data hash (challenge + keyId)
        let clientData = "\(challenge)|\(keyIdentifier)"
        guard let clientDataHash = clientData.data(using: .utf8)?.sha256() else {
            throw AppAttestError.hashingFailed
        }

        // Step 4: Get attestation from Apple
        let attestation = try await service.attestKey(keyIdentifier, clientDataHash: clientDataHash)

        // Step 5: Send attestation to server
        let attestationBase64 = attestation.base64EncodedString()
        try await apiClient.submitAttestation(keyId: keyIdentifier, attestation: attestationBase64)

        isAttested = true
        NSLog("[CutiE] App Attest: Device successfully attested")
        #else
        throw AppAttestError.notSupported
        #endif
    }

    /// Generate an assertion for a request
    /// - Parameters:
    ///   - clientData: The data to sign (typically request body hash)
    /// - Returns: Base64-encoded assertion
    public func generateAssertion(for clientData: Data) async throws -> String {
        #if canImport(DeviceCheck)
        guard isSupported else {
            throw AppAttestError.notSupported
        }

        guard let keyIdentifier = keyId, isAttested else {
            throw AppAttestError.notAttested
        }

        let service = DCAppAttestService.shared
        let clientDataHash = clientData.sha256()

        let assertion = try await service.generateAssertion(keyIdentifier, clientDataHash: clientDataHash)
        return assertion.base64EncodedString()
        #else
        throw AppAttestError.notSupported
        #endif
    }

    /// Reset attestation (for testing or re-attestation)
    public func reset() {
        keyId = nil
        isAttested = false
        NSLog("[CutiE] App Attest: Attestation reset")
    }

    /// Check attestation status with server
    /// - Parameter apiClient: API client for server communication
    /// - Returns: AttestationStatus from server
    internal func checkStatus(apiClient: CutiEAPIClient) async throws -> AttestationStatus {
        return try await apiClient.getAttestStatus()
    }
}

// MARK: - Error Types

/// App Attest specific errors
public enum AppAttestError: LocalizedError {
    case notSupported
    case notAttested
    case hashingFailed
    case keyGenerationFailed
    case attestationFailed(Error)
    case assertionFailed(Error)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "App Attest is not supported on this device"
        case .notAttested:
            return "Device not attested. Call performAttestation() first."
        case .hashingFailed:
            return "Failed to create client data hash"
        case .keyGenerationFailed:
            return "Failed to generate key pair"
        case .attestationFailed(let error):
            return "Attestation failed: \(error.localizedDescription)"
        case .assertionFailed(let error):
            return "Assertion generation failed: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Models

/// Attestation status response from server
public struct AttestationStatus: Codable {
    public let attested: Bool
    public let attestation: AttestationInfo?
}

/// Attestation info from server
public struct AttestationInfo: Codable {
    public let keyId: String
    public let environment: String
    public let signCount: Int
    public let createdAt: Int64
    public let lastAssertionAt: Int64?

    enum CodingKeys: String, CodingKey {
        case keyId = "key_id"
        case environment
        case signCount = "sign_count"
        case createdAt = "created_at"
        case lastAssertionAt = "last_assertion_at"
    }
}

/// Challenge response from server
internal struct AttestChallengeResponse: Codable {
    let challenge: String
    let expiresAt: Int64
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case challenge
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
    }
}

/// Attestation submission response
internal struct AttestResponse: Codable {
    let success: Bool
    let attestationId: String
    let attested: Bool

    enum CodingKeys: String, CodingKey {
        case success
        case attestationId = "attestation_id"
        case attested
    }
}

// MARK: - Helper Extensions

/// Simple Keychain helper for storing App Attest key ID
private enum KeychainHelper {
    static func setString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func getString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Data extension for SHA256 hashing
extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
