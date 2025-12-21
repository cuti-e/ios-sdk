import Foundation
import CommonCrypto
import Security

/// Manages SSL certificate pinning for secure API communication
/// Pins to Google Trust Services root CAs used by Cloudflare
internal final class CutiECertificatePinning: NSObject {

    static let shared = CutiECertificatePinning()

    // MARK: - Expiry Monitoring

    /// Certificate pin expiry date: June 22, 2036 00:00:00 UTC
    /// This is when the Google Trust Services root CAs expire
    private static let pinExpiryDate: Date = {
        var components = DateComponents()
        components.year = 2036
        components.month = 6
        components.day = 22
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date.distantFuture
    }()

    /// Number of days before expiry to start warning (1 year)
    private static let expiryWarningThresholdDays: Int = 365

    // MARK: - Certificate Pins

    /// SPKI SHA-256 hashes for Google Trust Services Root CAs
    /// These are stable root certificates that won't rotate with Cloudflare's leaf certs
    /// All expire: June 22, 2036
    private let pinnedHashes: Set<String> = [
        // GTS Root R1 (RSA 4096-bit)
        "hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=",
        // GTS Root R2 (RSA 4096-bit)
        "Vfd95BwDeSQo+NUYxVEEIlvkOlWY2SalKK1lPhzOx78=",
        // GTS Root R3 (ECC 384-bit)
        "QXnt2YHvdHR3tJYmQIr0Paosp6t/nggsEGD4QJZ3Q0g=",
        // GTS Root R4 (ECC 384-bit) - Currently used by Cloudflare
        "mEflZT5enoR1FuXLgYYGqnVEoZvmf9c2bVBpiOjYQ0c=",
        // WE1 Intermediate (current Cloudflare intermediate)
        "kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=",
    ]

    /// Domains that require certificate pinning
    private let pinnedDomains: Set<String> = [
        "api.cuti-e.com",
        "cutie-worker-sandbox.invotekas.workers.dev",
        "invotekas.workers.dev"
    ]

    private override init() {
        super.init()
        Self.checkPinExpiry()
    }

    // MARK: - Expiry Check

    /// Check if certificate pins are approaching expiry and log a warning
    /// Called automatically on initialization and can be called manually
    static func checkPinExpiry() {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        guard let daysUntilExpiry = calendar.dateComponents([.day], from: now, to: pinExpiryDate).day else {
            return
        }

        if daysUntilExpiry < 0 {
            NSLog("[CutiE] CRITICAL: Certificate pins have EXPIRED! Update the SDK immediately.")
        } else if daysUntilExpiry < expiryWarningThresholdDays {
            NSLog("[CutiE] WARNING: Certificate pins expire in %d days (June 22, 2036). Plan SDK update.", daysUntilExpiry)
        }
    }

    /// Returns the number of days until certificate pins expire
    /// Useful for monitoring and alerting
    static func daysUntilPinExpiry() -> Int {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents([.day], from: Date(), to: pinExpiryDate).day ?? 0
    }

    /// Create a URLSession with certificate pinning enabled
    func createPinnedSession(configuration: URLSessionConfiguration = .default) -> URLSession {
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }

    /// Check if a host requires certificate pinning
    func requiresPinning(for host: String) -> Bool {
        return pinnedDomains.contains(host) ||
               pinnedDomains.contains(where: { host.hasSuffix(".\($0)") })
    }

    /// Validate a certificate chain against pinned hashes
    func validateCertificateChain(_ trust: SecTrust) -> Bool {
        guard let certificateChain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
            return false
        }

        for certificate in certificateChain {
            if let publicKeyHash = getPublicKeyHash(for: certificate) {
                if pinnedHashes.contains(publicKeyHash) {
                    return true
                }
            }
        }

        return false
    }

    /// Extract and hash the public key from a certificate
    private func getPublicKeyHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        guard let attributes = SecKeyCopyAttributes(publicKey) as? [String: Any],
              let keyType = attributes[kSecAttrKeyType as String] as? String else {
            return nil
        }

        let spkiHeader: Data
        if keyType == (kSecAttrKeyTypeRSA as String) {
            spkiHeader = Data([
                0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09,
                0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
                0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
            ])
        } else if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) {
            let keySize = (attributes[kSecAttrKeySizeInBits as String] as? Int) ?? 256
            if keySize == 256 {
                spkiHeader = Data([
                    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86,
                    0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
                    0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
                    0x42, 0x00
                ])
            } else if keySize == 384 {
                spkiHeader = Data([
                    0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86,
                    0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x05, 0x2b,
                    0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
                ])
            } else {
                return nil
            }
        } else {
            return nil
        }

        var spkiData = spkiHeader
        spkiData.append(publicKeyData)

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        spkiData.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(spkiData.count), &hash)
        }

        return Data(hash).base64EncodedString()
    }
}

// MARK: - URLSessionDelegate

extension CutiECertificatePinning: URLSessionDelegate {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        guard requiresPinning(for: host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var error: CFError?
        let isServerTrusted = SecTrustEvaluateWithError(serverTrust, &error)

        guard isServerTrusted else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if validateCertificateChain(serverTrust) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

extension CutiECertificatePinning: URLSessionTaskDelegate {

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        urlSession(session, didReceive: challenge, completionHandler: completionHandler)
    }
}
