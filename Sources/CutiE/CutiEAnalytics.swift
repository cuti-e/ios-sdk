import Foundation
import CommonCrypto

#if canImport(UIKit)
import UIKit
#endif

/// Manages anonymous activity tracking with user consent (GDPR-compliant).
///
/// Activity pings are fire-and-forget — failures are silently ignored.
/// The hashed device ID is pseudonymized (SHA256 of identifierForVendor + bundleID).
/// Consent is opt-in (default OFF) and persisted in UserDefaults.
internal class CutiEAnalytics {

    static let shared = CutiEAnalytics()

    // MARK: - UserDefaults Keys

    private let consentKey = "com.cutie.analyticsConsent"
    private let consentAskedKey = "com.cutie.analyticsConsentAsked"

    // MARK: - State

    /// Whether the user has granted analytics consent
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: consentKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: consentKey)
            UserDefaults.standard.set(true, forKey: consentAskedKey)
            if newValue {
                startObservingLifecycle()
                sendActivityPingIfNeeded()
            } else {
                stopObservingLifecycle()
            }
        }
    }

    /// Whether the user has been asked for analytics consent
    var hasBeenAsked: Bool {
        UserDefaults.standard.bool(forKey: consentAskedKey)
    }

    /// Prevents sending more than one ping per app launch
    private var hasSentPingThisLaunch = false

    /// Whether lifecycle observer is active
    private var isObserving = false

    private init() {}

    // MARK: - SDK Lifecycle

    /// Called from CutiE.configure() after SDK is ready.
    /// Starts lifecycle observation if consent was previously granted.
    func onSDKConfigured() {
        if isEnabled {
            startObservingLifecycle()
            sendActivityPingIfNeeded()
        }
    }

    // MARK: - Lifecycle Observation

    private func startObservingLifecycle() {
        guard !isObserving else { return }
        isObserving = true

        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    private func stopObservingLifecycle() {
        guard isObserving else { return }
        isObserving = false

        #if os(iOS)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    @objc private func appDidBecomeActive() {
        sendActivityPingIfNeeded()
    }

    // MARK: - Activity Ping

    func sendActivityPingIfNeeded() {
        guard isEnabled else { return }
        guard !hasSentPingThisLaunch else { return }
        guard let client = CutiE.shared.apiClient else { return }

        hasSentPingThisLaunch = true

        let hashedID = generateHashedDeviceID()
        client.sendActivityPing(hashedDeviceID: hashedID)
    }

    // MARK: - Hashed Device ID

    /// Generate a SHA256 hash of identifierForVendor + bundleID.
    /// Returns a 64-character hex string. Falls back to the SDK device ID if
    /// identifierForVendor is unavailable (e.g., on macOS or simulator edge cases).
    func generateHashedDeviceID() -> String {
        var base: String

        #if os(iOS)
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
            base = vendorID
        } else {
            base = CutiE.shared.configuration?.deviceID ?? UUID().uuidString
        }
        #else
        base = CutiE.shared.configuration?.deviceID ?? UUID().uuidString
        #endif

        if let bundleID = Bundle.main.bundleIdentifier {
            base += bundleID
        }

        guard let data = base.data(using: .utf8) else { return "" }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Testing Support

    /// Reset state for unit tests
    internal func resetForTesting() {
        hasSentPingThisLaunch = false
        stopObservingLifecycle()
        UserDefaults.standard.removeObject(forKey: consentKey)
        UserDefaults.standard.removeObject(forKey: consentAskedKey)
    }
}
