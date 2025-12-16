import Foundation

#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// Manages Apple App Attest for cryptographic device verification.
///
/// `CutiEAppAttest` uses Apple's `DCAppAttestService` to cryptographically verify
/// that API requests come from legitimate installations of your app on genuine Apple devices.
/// This provides protection against request tampering and ensures requests originate from
/// unmodified versions of your app.
///
/// ## Overview
///
/// App Attest works by generating a unique key pair on the device's Secure Enclave,
/// then attesting that key with Apple's servers. Once attested, the SDK can generate
/// signed assertions for API requests.
///
/// ## Enabling App Attest
///
/// Enable App Attest during SDK configuration:
///
/// ```swift
/// CutiE.shared.configure(
///     appId: "your_app_id",
///     useAppAttest: true
/// )
/// ```
///
/// The SDK automatically handles:
/// - Key generation on first launch
/// - Attestation with Apple and your backend
/// - Assertion generation for protected requests
/// - Graceful fallback on unsupported devices
///
/// ## Device Support
///
/// App Attest requires:
/// - iOS 14.0+ or macOS 11.0+
/// - A physical device (not supported on simulators)
/// - Devices with Secure Enclave (iPhone 5s and later)
///
/// ## Topics
///
/// ### Checking Support
///
/// - ``isSupported``
/// - ``isAttested``
///
/// ### Generating Assertions
///
/// - ``generateAssertion(for:)``
///
/// ### Managing Attestation
///
/// - ``reset()``
@available(iOS 14.0, macOS 11.0, *)
public class CutiEAppAttest {

    /// The shared singleton instance.
    ///
    /// Access the App Attest manager through this property:
    /// ```swift
    /// let appAttest = CutiE.shared.appAttest
    /// ```
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

    /// Indicates whether this device has completed attestation.
    ///
    /// Returns `true` after the device has successfully completed the attestation flow
    /// with both Apple and your backend server. Once attested, the device can generate
    /// signed assertions for API requests.
    ///
    /// ```swift
    /// if CutiE.shared.appAttest.isAttested {
    ///     // Device is verified, can use enhanced security features
    /// }
    /// ```
    ///
    /// - Note: This property persists across app launches. Call ``reset()`` to clear
    ///   attestation state and re-attest the device.
    public private(set) var isAttested: Bool = false

    /// Indicates whether App Attest is supported on this device.
    ///
    /// Returns `true` if the device meets all requirements for App Attest:
    /// - Running iOS 14.0+ or macOS 11.0+
    /// - Physical device (not a simulator)
    /// - Has Secure Enclave hardware
    ///
    /// ```swift
    /// if CutiE.shared.appAttest.isSupported {
    ///     print("App Attest available")
    /// } else {
    ///     print("App Attest not supported on this device")
    /// }
    /// ```
    ///
    /// - Important: Always check this property before attempting attestation-related operations.
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

    /// Generates a cryptographic assertion for API request signing.
    ///
    /// Use this method to generate a signed assertion that proves the request
    /// originates from an attested device. The assertion is generated using
    /// the device's private key stored in the Secure Enclave.
    ///
    /// ```swift
    /// // Hash the request body
    /// let bodyData = try JSONEncoder().encode(requestBody)
    ///
    /// // Generate assertion
    /// let assertion = try await CutiE.shared.appAttest.generateAssertion(for: bodyData)
    ///
    /// // Include assertion in request header
    /// request.setValue(assertion, forHTTPHeaderField: "X-App-Assertion")
    /// ```
    ///
    /// - Parameter clientData: The data to sign, typically a hash of the request body.
    ///   This ensures the assertion is bound to specific request content.
    ///
    /// - Returns: A Base64-encoded assertion string suitable for inclusion in HTTP headers.
    ///
    /// - Throws: ``AppAttestError/notSupported`` if App Attest is unavailable,
    ///   ``AppAttestError/notAttested`` if the device hasn't completed attestation,
    ///   or ``AppAttestError/assertionFailed(_:)`` if assertion generation fails.
    ///
    /// - Important: The device must be attested (``isAttested`` is `true`) before
    ///   calling this method.
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

    /// Resets attestation state to allow re-attestation.
    ///
    /// Call this method to clear the stored attestation key and allow the device
    /// to go through the attestation flow again. This is useful for:
    /// - Testing attestation in development
    /// - Recovering from attestation errors
    /// - Forcing re-attestation after backend key revocation
    ///
    /// ```swift
    /// // Clear attestation and re-attest
    /// CutiE.shared.appAttest.reset()
    ///
    /// // Attestation will happen automatically on next API call
    /// // if useAppAttest was enabled during configuration
    /// ```
    ///
    /// - Warning: After calling reset, the device will need to complete the full
    ///   attestation flow again, which requires network connectivity and may take
    ///   a few seconds.
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
