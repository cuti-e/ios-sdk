import Foundation
import CommonCrypto

#if canImport(UIKit)
import UIKit
#endif

/// Outcome of a single activity ping attempt.
///
/// The SDK does not retry HTTP failures — a rejected ping is recorded, not re-sent.
internal enum CutiEActivityPingOutcome {
    /// The server accepted the ping (2xx).
    case delivered(statusCode: Int)
    /// The server answered with an error status (4xx/5xx).
    case rejected(statusCode: Int)
    /// The request never got an HTTP answer (offline, DNS, timeout, ...).
    case transportFailure(reason: String)
}

/// Read-only diagnostics for anonymous activity pings.
///
/// Exposed so a host app can surface "analytics are being refused" instead of the SDK
/// swallowing it. Nothing here identifies a device: only counters, an HTTP status code
/// and a non-identifying reason string.
public struct CutiEActivityPingDiagnostics: Equatable {
    /// When the most recent ping attempt completed.
    public let lastAttemptDate: Date?
    /// HTTP status of the most recent attempt that got an answer, if any.
    public let lastStatusCode: Int?
    /// Non-identifying reason for the most recent failure (e.g. `http_401`, `urlerror_-1009`).
    public let lastFailureReason: String?
    /// UTC day (`yyyy-MM-dd`) of the most recent recorded ping, if any.
    public let lastPingDay: String?
    /// Pings accepted by the server (2xx).
    public let deliveredCount: Int
    /// Pings answered with an HTTP error (4xx/5xx).
    public let rejectedCount: Int
    /// Pings that never reached the server, after the single retry.
    public let transportFailureCount: Int
}

/// Manages anonymous activity tracking with user consent (GDPR-compliant).
///
/// A consenting device pings **at most once per UTC day**: the last ping day is persisted in
/// UserDefaults, so returning to a backgrounded app after midnight UTC pings again, and a second
/// launch on the same day does not. The hashed device ID is pseudonymized
/// (SHA256 of identifierForVendor + bundleID). Consent is opt-in (default OFF) and persisted
/// in UserDefaults.
///
/// Ping outcomes are recorded in ``CutiEActivityPingDiagnostics`` — a refused ping is visible
/// to the host app rather than silently discarded. No diagnostics are ever sent anywhere.
internal class CutiEAnalytics {

    static let shared = CutiEAnalytics()

    // MARK: - UserDefaults Keys

    private let consentKey = "com.cutie.analyticsConsent"
    private let consentAskedKey = "com.cutie.analyticsConsentAsked"
    private let lastPingDayKey = "com.cutie.analyticsLastPingDay"

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

    /// Whether lifecycle observer is active
    private(set) var isObserving = false

    /// Clock, overridable in tests so a day boundary can be crossed deterministically.
    internal var dateProvider: () -> Date = { Date() }

    /// Transport override for tests. When set, no URLSession work happens.
    internal var pingTransportOverride: ((String, @escaping (CutiEActivityPingOutcome) -> Void) -> Void)?

    private let diagnosticsLock = NSLock()
    private var lastAttemptDate: Date?
    private var lastStatusCode: Int?
    private var lastFailureReason: String?
    private var deliveredCount = 0
    private var rejectedCount = 0
    private var transportFailureCount = 0

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

    /// Foreground hook. Reachable in practice: the per-day guard (not a per-launch flag) decides
    /// whether this pings, so an app resumed after midnight UTC pings without a relaunch.
    @objc internal func appDidBecomeActive() {
        sendActivityPingIfNeeded()
    }

    // MARK: - Activity Ping

    /// UTC day of the most recent recorded ping (`yyyy-MM-dd`), or nil if never pinged.
    internal var lastPingDay: String? {
        UserDefaults.standard.string(forKey: lastPingDayKey)
    }

    /// Send an activity ping if consent is on and this device has not pinged yet today (UTC).
    func sendActivityPingIfNeeded() {
        guard isEnabled else { return }

        let today = Self.utcDayString(from: dateProvider())
        guard lastPingDay != today else { return }

        let hashedID = generateHashedDeviceID()

        if let override = pingTransportOverride {
            UserDefaults.standard.set(today, forKey: lastPingDayKey)
            override(hashedID) { [weak self] outcome in
                self?.record(outcome)
            }
            return
        }

        // Not configured yet — do not burn today's ping; try again once configure() runs.
        guard let client = CutiE.shared.apiClient else { return }

        // Marked before the request so a failure cannot turn into a retry storm:
        // at most one network call per device per UTC day.
        UserDefaults.standard.set(today, forKey: lastPingDayKey)

        client.sendActivityPing(hashedDeviceID: hashedID) { [weak self] outcome in
            self?.record(outcome)
        }
    }

    /// UTC calendar day, matching the `ping_date` granularity the backend stores.
    private static let utcDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    internal static func utcDayString(from date: Date) -> String {
        utcDayFormatter.string(from: date)
    }

    // MARK: - Diagnostics

    /// Snapshot of ping outcomes. Safe to read from any thread.
    internal var diagnostics: CutiEActivityPingDiagnostics {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }
        return CutiEActivityPingDiagnostics(
            lastAttemptDate: lastAttemptDate,
            lastStatusCode: lastStatusCode,
            lastFailureReason: lastFailureReason,
            lastPingDay: lastPingDay,
            deliveredCount: deliveredCount,
            rejectedCount: rejectedCount,
            transportFailureCount: transportFailureCount
        )
    }

    /// Record the outcome of one ping. Logs failures without any device identifier.
    internal func record(_ outcome: CutiEActivityPingOutcome) {
        diagnosticsLock.lock()
        lastAttemptDate = dateProvider()

        switch outcome {
        case .delivered(let statusCode):
            deliveredCount += 1
            lastStatusCode = statusCode
            lastFailureReason = nil
        case .rejected(let statusCode):
            rejectedCount += 1
            lastStatusCode = statusCode
            lastFailureReason = "http_\(statusCode)"
        case .transportFailure(let reason):
            transportFailureCount += 1
            lastStatusCode = nil
            lastFailureReason = reason
        }
        let reason = lastFailureReason
        diagnosticsLock.unlock()

        if let reason = reason {
            // Status/reason only — never the hashed device ID or any identifier.
            NSLog("[CutiE] Activity ping not recorded by server (%@)", reason)
        }
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
        stopObservingLifecycle()
        dateProvider = { Date() }
        pingTransportOverride = nil
        UserDefaults.standard.removeObject(forKey: consentKey)
        UserDefaults.standard.removeObject(forKey: consentAskedKey)
        UserDefaults.standard.removeObject(forKey: lastPingDayKey)

        diagnosticsLock.lock()
        lastAttemptDate = nil
        lastStatusCode = nil
        lastFailureReason = nil
        deliveredCount = 0
        rejectedCount = 0
        transportFailureCount = 0
        diagnosticsLock.unlock()
    }
}
