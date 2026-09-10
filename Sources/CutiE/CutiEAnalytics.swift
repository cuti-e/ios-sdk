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
    /// UTC day (`yyyy-MM-dd`) of the most recent ping the server answered, if any.
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
/// A consenting device is counted **at most once per UTC day**: the day of the last ping the
/// server *answered* is persisted in UserDefaults, so returning to a backgrounded app after
/// midnight UTC pings again, and a second launch on the same day does not. The hashed device ID
/// is pseudonymized (SHA256 of identifierForVendor + bundleID). Consent is opt-in (default OFF)
/// and persisted in UserDefaults.
///
/// Two properties this class exists to guarantee:
///
/// - **A failed attempt never costs the device its day.** The day marker is written when an HTTP
///   answer arrives, not when the request leaves. A device that was used but could not reach the
///   network re-attempts on a later foreground instead of silently vanishing from DAU. Attempts
///   are bounded by a cooldown and a per-day cap, so "retry later" cannot become a retry storm.
///   Double counting is impossible regardless: the server deduplicates on
///   `UNIQUE(app_id, hashed_device_id, ping_date)` using its own UTC date.
/// - **A background wake is not a use.** A ping raised while the process is in the background
///   (background fetch, silent push) is skipped, so a day nobody opened the app reports nobody.
///
/// Ping outcomes are recorded in ``CutiEActivityPingDiagnostics`` — a refused ping is visible
/// to the host app rather than silently discarded. No diagnostics are ever sent anywhere.
internal class CutiEAnalytics {

    static let shared = CutiEAnalytics()

    // MARK: - UserDefaults Keys

    private let consentKey = "com.cutie.analyticsConsent"
    private let consentAskedKey = "com.cutie.analyticsConsentAsked"
    private let lastPingDayKey = "com.cutie.analyticsLastPingDay"
    private let lastAttemptAtKey = "com.cutie.analyticsLastPingAttemptAt"
    private let attemptDayKey = "com.cutie.analyticsPingAttemptDay"
    private let attemptCountKey = "com.cutie.analyticsPingAttemptCount"

    // MARK: - Attempt Bounds

    /// Minimum gap between two ping attempts on a day that has not been answered yet.
    internal static let attemptCooldown: TimeInterval = 15 * 60

    /// Hard cap on attempts per UTC day. Reached only if every attempt failed in transport.
    internal static let maxAttemptsPerDay = 5

    // MARK: - State

    /// Whether the user has granted analytics consent
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: consentKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: consentKey)
            UserDefaults.standard.set(true, forKey: consentAskedKey)
            if newValue {
                startObservingLifecycle()
                // Consent is granted by a person tapping something, so the app is in front.
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

    /// Guards the ping decision (day marker, attempt bookkeeping, in-flight flag), the
    /// lifecycle-observer token and the test overrides. Recursive so an accessor taken inside
    /// the decision cannot deadlock.
    private let stateLock = NSRecursiveLock()

    /// Live foreground observer, or nil when not observing. The token *is* the state — a Bool
    /// set next to the registration can claim an observer that was never installed.
    private var foregroundObserver: NSObjectProtocol?

    /// Whether lifecycle observer is active
    var isObserving: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return foregroundObserver != nil
    }

    /// When the in-flight ping started, or nil when none is on its way. Two callers on two
    /// queues cannot both send. Timestamped rather than a plain Bool because a completion can be
    /// lost (iOS suspends the process while the single retry is waiting), and a wedged flag would
    /// silently stop every later ping in this process.
    private var pingInFlightSince: Date?

    /// After this long an in-flight ping is assumed lost and a new attempt is allowed.
    internal static let inFlightTimeout: TimeInterval = 60

    private var _dateProvider: () -> Date = { Date() }
    /// Clock, overridable in tests so a day boundary can be crossed deterministically.
    internal var dateProvider: () -> Date {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _dateProvider }
        set { stateLock.lock(); _dateProvider = newValue; stateLock.unlock() }
    }

    private var _pingTransportOverride: ((String, @escaping (CutiEActivityPingOutcome) -> Void) -> Void)?
    /// Transport override for tests. When set, no URLSession work happens.
    internal var pingTransportOverride: ((String, @escaping (CutiEActivityPingOutcome) -> Void) -> Void)? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _pingTransportOverride }
        set { stateLock.lock(); _pingTransportOverride = newValue; stateLock.unlock() }
    }

    private var _isInBackgroundProvider: () -> Bool = CutiEAnalytics.defaultIsInBackground
    /// Whether the host process is currently in the background. Overridable in tests so the
    /// background-launch rule is exercised on every platform, not only on a device.
    internal var isInBackgroundProvider: () -> Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isInBackgroundProvider }
        set { stateLock.lock(); _isInBackgroundProvider = newValue; stateLock.unlock() }
    }

    /// Reads the real application state. Only ever called on the main thread (see
    /// ``sendActivityPingIfNeeded(requireForeground:)``), because UIApplication is main-thread only.
    private static let defaultIsInBackground: () -> Bool = {
        #if os(iOS)
        return UIApplication.shared.applicationState == .background
        #else
        return false
        #endif
    }

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
    ///
    /// A background launch (background fetch, silent push, background URLSession completion) also
    /// runs configure(), so this path insists on the foreground: otherwise a day the human never
    /// opened the app would report a daily active user.
    func onSDKConfigured() {
        if isEnabled {
            startObservingLifecycle()
            sendActivityPingIfNeeded(requireForeground: true)
        }
    }

    // MARK: - Lifecycle Observation

    /// Notification that means "the app came to the foreground".
    ///
    /// On iOS this is the real UIKit notification. Elsewhere it is an internal name, so the
    /// registration itself — not just a bookkeeping flag — is exercised by the test suite, which
    /// runs on macOS. Deleting the registration therefore fails a test.
    internal static let didBecomeActiveNotification: Notification.Name = {
        #if os(iOS)
        return UIApplication.didBecomeActiveNotification
        #else
        return Notification.Name("com.cutie.analytics.didBecomeActive")
        #endif
    }()

    private func startObservingLifecycle() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard foregroundObserver == nil else { return }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: Self.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.appDidBecomeActive()
        }
    }

    private func stopObservingLifecycle() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let observer = foregroundObserver else { return }

        NotificationCenter.default.removeObserver(observer)
        foregroundObserver = nil
    }

    /// Foreground hook. Reachable in practice: the per-day guard (not a per-launch flag) decides
    /// whether this pings, so an app resumed after midnight UTC pings without a relaunch, and a
    /// day whose only attempt failed is re-attempted here rather than lost.
    internal func appDidBecomeActive() {
        // The app is by definition in front here, so no foreground check is needed.
        sendActivityPingIfNeeded()
    }

    // MARK: - Activity Ping

    /// UTC day of the most recent ping the server answered (`yyyy-MM-dd`), or nil if never.
    internal var lastPingDay: String? {
        UserDefaults.standard.string(forKey: lastPingDayKey)
    }

    /// Send an activity ping if consent is on and this device has not been counted yet today (UTC).
    ///
    /// - Parameter requireForeground: skip the ping when the process is in the background. Set on
    ///   the configure() path, where the launch may be a background wake rather than a person.
    func sendActivityPingIfNeeded(requireForeground: Bool = false) {
        guard isEnabled else { return }

        if requireForeground {
            #if os(iOS)
            // UIApplication.applicationState is main-thread only, and configure() is often called
            // off the launch path. Hop instead of reading UIKit from a background queue.
            if !Thread.isMainThread {
                DispatchQueue.main.async { [weak self] in
                    self?.sendActivityPingIfNeeded(requireForeground: true)
                }
                return
            }
            #endif
            if isInBackgroundProvider() { return }
        }

        let now = dateProvider()
        let today = Self.utcDayString(from: now)

        // One decision, one writer: the read-decide-mark sequence below runs under the lock, so
        // two callers on two queues cannot both conclude "not sent yet today".
        stateLock.lock()

        if let since = pingInFlightSince, now.timeIntervalSince(since) < Self.inFlightTimeout {
            stateLock.unlock()
            return
        }
        guard UserDefaults.standard.string(forKey: lastPingDayKey) != today else {
            stateLock.unlock()
            return
        }
        guard let transport = currentTransportLocked() else {
            // Not configured yet — nothing was attempted, so nothing is spent. configure() retries.
            stateLock.unlock()
            return
        }
        guard mayAttemptLocked(today: today, now: now) else { stateLock.unlock(); return }

        recordAttemptLocked(today: today, now: now)
        pingInFlightSince = now
        stateLock.unlock()

        let hashedID = generateHashedDeviceID()
        transport(hashedID) { [weak self] outcome in
            self?.finishPing(outcome, day: today)
        }
    }

    /// The transport to use: the test override if set, otherwise the configured API client.
    /// Must be called with `stateLock` held.
    private func currentTransportLocked() -> ((String, @escaping (CutiEActivityPingOutcome) -> Void) -> Void)? {
        if let override = _pingTransportOverride { return override }
        guard let client = CutiE.shared.apiClient else { return nil }
        return { hashedID, completion in
            client.sendActivityPing(hashedDeviceID: hashedID, completion: completion)
        }
    }

    /// Whether another attempt is allowed for a day that has not been answered yet.
    /// Must be called with `stateLock` held.
    private func mayAttemptLocked(today: String, now: Date) -> Bool {
        let defaults = UserDefaults.standard

        // A fresh UTC day resets the budget.
        if defaults.string(forKey: attemptDayKey) == today {
            if defaults.integer(forKey: attemptCountKey) >= Self.maxAttemptsPerDay { return false }
            if let lastAttemptAt = defaults.object(forKey: lastAttemptAtKey) as? Double,
               now.timeIntervalSince1970 - lastAttemptAt < Self.attemptCooldown {
                return false
            }
        }
        return true
    }

    /// Must be called with `stateLock` held.
    private func recordAttemptLocked(today: String, now: Date) {
        let defaults = UserDefaults.standard
        let attemptsToday = defaults.string(forKey: attemptDayKey) == today
            ? defaults.integer(forKey: attemptCountKey)
            : 0

        defaults.set(today, forKey: attemptDayKey)
        defaults.set(attemptsToday + 1, forKey: attemptCountKey)
        defaults.set(now.timeIntervalSince1970, forKey: lastAttemptAtKey)
    }

    /// Settle one attempt.
    ///
    /// The day is marked only when the server actually answered — delivered *or* refused. A
    /// transport failure leaves the day open, because nothing reached the server: no
    /// `activity_pings` row, no `activity_ping_rejections` row, so silently spending the day
    /// would turn a used device into an invisible one.
    private func finishPing(_ outcome: CutiEActivityPingOutcome, day: String) {
        stateLock.lock()
        pingInFlightSince = nil
        switch outcome {
        case .delivered, .rejected:
            UserDefaults.standard.set(day, forKey: lastPingDayKey)
        case .transportFailure:
            break
        }
        stateLock.unlock()

        record(outcome)
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
        let day = lastPingDay
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }
        return CutiEActivityPingDiagnostics(
            lastAttemptDate: lastAttemptDate,
            lastStatusCode: lastStatusCode,
            lastFailureReason: lastFailureReason,
            lastPingDay: day,
            deliveredCount: deliveredCount,
            rejectedCount: rejectedCount,
            transportFailureCount: transportFailureCount
        )
    }

    /// Record the outcome of one ping. Logs failures without any device identifier.
    internal func record(_ outcome: CutiEActivityPingOutcome) {
        // Read the clock before taking the counters lock: locks are only ever taken in the order
        // stateLock -> diagnosticsLock, never the reverse.
        let attemptedAt = dateProvider()

        diagnosticsLock.lock()
        lastAttemptDate = attemptedAt

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

        stateLock.lock()
        _dateProvider = { Date() }
        _pingTransportOverride = nil
        _isInBackgroundProvider = Self.defaultIsInBackground
        pingInFlightSince = nil
        for key in [consentKey, consentAskedKey, lastPingDayKey, lastAttemptAtKey, attemptDayKey, attemptCountKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        stateLock.unlock()

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
