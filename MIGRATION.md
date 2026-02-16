# Migration Guide

This guide helps you migrate between versions of the CutiE iOS SDK.

## Table of Contents

- [Migrating to 2.2.0 (Compose Button & showFeedback)](#migrating-to-220-compose-button--showfeedback)
- [Migrating to 2.1.0 (Deep-link Navigation)](#migrating-to-210-deep-link-navigation)
- [Migrating to 2.0.0 (SubscriptionManager Removal)](#migrating-to-200-subscriptionmanager-removal)
- [Migrating to 1.0.102+ (API Key Removal)](#migrating-to-10102-api-key-removal)
- [Migrating to 1.0.104+ (Push Token Validation)](#migrating-to-10104-push-token-validation)
- [Adding Optional Features](#adding-optional-features)
  - [App Attest](#adding-app-attest)
  - [Push Notifications](#adding-push-notifications)
  - [Device Linking](#adding-device-linking)
- [Troubleshooting](#troubleshooting)

---

## Migrating to 2.2.0 (Compose Button & showFeedback)

**Version 2.2.0** adds a compose button to the inbox and a new `showFeedback()` API for presenting the feedback form programmatically.

### Inbox Compose Button

The inbox now includes a compose button (pencil icon) in the toolbar alongside the refresh button. Users can tap it to open the feedback form directly from the inbox. The empty state also shows a "Send Feedback" button for discoverability.

No code changes required - the compose button is built into `CutiEInboxView`.

### New: showFeedback() API

Present the feedback form programmatically from UIKit, mirroring the existing `showInbox()` pattern:

```swift
// Present feedback form
CutiE.shared.showFeedback()

// With success callback
CutiE.shared.showFeedback { conversationId in
    print("Feedback submitted: \(conversationId)")
}

// From a specific view controller
CutiE.shared.showFeedback(from: self)
```

### Backward Compatibility

All changes are additive. Existing code continues to work without modifications.

---

## Migrating to 2.1.0 (Deep-link Navigation)

**Version 2.1.0** adds deep-link navigation support, allowing you to open the inbox directly to a specific conversation or scroll to a specific message.

### New Parameters

**`showInbox(conversationId:)`** - Navigate directly to a conversation (e.g., from a push notification):

```swift
// Before: opens inbox at conversation list
CutiE.shared.showInbox()

// After: opens inbox and navigates to a specific conversation
CutiE.shared.showInbox(conversationId: "conv_abc123")
```

**`CutiEInboxView(conversationId:)`** - SwiftUI deep-link support:

```swift
// Before
CutiEInboxView()

// After: deep-link to a conversation
CutiEInboxView(conversationId: "conv_abc123")
```

**`CutiEConversationView(conversation:targetMessageId:)`** - Scroll to a specific message:

```swift
// Before: scrolls to the latest message
CutiEConversationView(conversation: conversation)

// After: scrolls to a specific message
CutiEConversationView(conversation: conversation, targetMessageId: "msg_xyz789")
```

### Push Notification Deep-linking

Use the new `conversationId` parameter in your notification delegate to navigate users directly to the relevant conversation:

```swift
func cutiEShouldOpenConversation(conversationId: String) {
    CutiE.shared.showInbox(conversationId: conversationId)
}
```

### Public Device Linking API

Device linking methods are now available directly on `CutiE.shared` (previously required accessing the internal `apiClient`):

```swift
// Before (did not compile - apiClient was internal)
let response = try await CutiE.shared.apiClient?.initiateLinkToken()

// After
let response = try await CutiE.shared.initiateLinkToken()
```

All five device linking methods are now public: `initiateLinkToken()`, `confirmLink(token:deviceName:)`, `checkLinkStatus(token:)`, `getLinkedDevices()`, `unlinkDevice(_:)`.

### Backward Compatibility

All new parameters are optional with `nil` defaults. Existing code continues to work without changes.

---

## Migrating to 2.0.0 (SubscriptionManager Removal)

**Version 2.0.0** removes `CutiESubscriptionManager`. Subscription management has moved to [RevenueCat](https://www.revenuecat.com).

### Breaking Change

If you were using `CutiESubscriptionManager`, you must remove all references:

```swift
// REMOVED in 2.0.0 - these will not compile
CutiE.shared.subscriptionManager.purchase(product)
CutiE.shared.subscriptionManager.restorePurchases()
CutiE.shared.subscriptionManager.getProducts()
```

### Migration Steps

1. **Remove all `CutiESubscriptionManager` usage** from your code
2. **Integrate RevenueCat SDK** if you need subscription management:
   ```swift
   // Package.swift
   .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.0.0")
   ```
3. **Replace subscription calls** with RevenueCat equivalents:
   ```swift
   import RevenueCat

   // Configure
   Purchases.configure(withAPIKey: "appl_your_key")

   // Purchase
   let result = try await Purchases.shared.purchase(package: package)

   // Check entitlements
   let info = try await Purchases.shared.customerInfo()
   let isPro = info.entitlements["pro"]?.isActive == true
   ```

### What Else Changed

- No other breaking changes in 2.0.0
- All conversation, inbox, push notification, and App Attest APIs remain unchanged

---

## Migrating to 1.0.102+ (API Key Removal)

**Version 1.0.102** introduced anonymous device registration, making API keys optional.

### Before (1.0.101 and earlier)

```swift
// Old way - API key required
CutiE.shared.configure(
    apiKey: "your_api_key",
    appId: "your_app_id"
)
```

### After (1.0.102+)

```swift
// New way - just App ID
CutiE.shared.configure(appId: "your_app_id")

// With custom API URL
CutiE.shared.configure(
    appId: "your_app_id",
    apiURL: "https://your-custom-api.example.com"
)
```

### Migration Steps

1. **Update your SDK version** to 1.0.102 or later in `Package.swift`:
   ```swift
   .package(url: "https://github.com/cuti-e/ios-sdk.git", from: "1.0.102")
   ```

2. **Remove the API key** from your `configure()` call:
   ```swift
   // Change this:
   CutiE.shared.configure(apiKey: "xxx", appId: "your_app_id")

   // To this:
   CutiE.shared.configure(appId: "your_app_id")
   ```

3. **Remove stored API keys** from your project (if any):
   - Delete from `Info.plist` if stored there
   - Remove from environment variables
   - Remove from any secrets management

### Backward Compatibility

The old `configure(apiKey:appId:)` method still works but shows a deprecation warning:

```
'configure(apiKey:appId:apiURL:)' is deprecated: API key is no longer required. Use configure(appId:) instead.
```

Your app will continue to work, but you should migrate to remove the warning.

### How It Works Now

Instead of API keys, the SDK now uses **anonymous device registration**:

1. On first launch, SDK generates a unique device ID
2. Device registers with the backend automatically
3. A device token is stored securely in the Keychain
4. All API calls are authenticated using this device token

This provides equivalent security without requiring you to manage API keys.

---

## Migrating to 1.0.104+ (Push Token Validation)

**Version 1.0.104** added input validation for push notification tokens.

### What Changed

The `registerToken()` method now validates tokens before sending to the backend:

```swift
// Now returns Result<Void, CutiEError>
let result = CutiE.shared.pushNotifications.registerToken(token)

switch result {
case .success:
    print("Token registered")
case .failure(let error):
    print("Invalid token: \(error.localizedDescription)")
}
```

### Validation Rules

Tokens must:
- Not be empty
- Be at least 32 characters
- Be at most 200 characters
- Contain only hexadecimal characters (0-9, a-f, A-F)

### Backward Compatibility

The method is marked `@discardableResult`, so existing code that ignores the return value will continue to work:

```swift
// This still works (result is discarded)
CutiE.shared.pushNotifications.registerToken(token)
```

However, invalid tokens are now rejected early instead of failing at the backend.

### New Error Type

A new error case was added:

```swift
case .invalidPushToken(let reason)
// Example: "Invalid push token: Token cannot be empty"
```

---

## Adding Optional Features

These features can be added to any version 1.0.97+.

### Adding App Attest

App Attest provides cryptographic device verification using Apple's Secure Enclave.

#### Requirements

- iOS 14.0+ / macOS 11.0+
- Real device (not simulator)

#### Enable App Attest

```swift
CutiE.shared.configure(
    appId: "your_app_id",
    useAppAttest: true  // Enable App Attest
)
```

#### Check Status

```swift
// Check if supported on this device
if CutiE.shared.appAttest.isSupported {
    print("App Attest available")
}

// Check if attested
if CutiE.shared.appAttest.isAttested {
    print("Device is verified")
}
```

#### Fallback Behavior

If App Attest is not supported (simulator, older devices), the SDK automatically falls back to standard authentication. No code changes required.

---

### Adding Push Notifications

Push notifications notify users when they receive responses to their feedback.

#### Prerequisites

1. **Xcode**: Add "Push Notifications" capability
2. **Apple Developer Portal**: Create APNs key (.p8 file)
3. **Cuti-E Admin**: Upload APNs credentials

See the [README Push Notifications section](README.md#push-notifications) for detailed setup.

#### Code Changes

**1. Request Permission**

```swift
// In your app startup or settings
CutiE.shared.pushNotifications.requestPermission { granted in
    print("Permission granted: \(granted)")
}
```

**2. Register Token (AppDelegate)**

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    CutiE.shared.pushNotifications.didRegisterForRemoteNotifications(
        withDeviceToken: deviceToken
    )
}

func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
) {
    CutiE.shared.pushNotifications.didFailToRegisterForRemoteNotifications(
        withError: error
    )
}
```

**3. Handle Notifications**

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        CutiE.shared.pushNotifications.handleNotification(
            notification.request.content.userInfo
        )
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        CutiE.shared.pushNotifications.handleNotificationTap(
            response.notification.request.content.userInfo
        )
        completionHandler()
    }
}
```

---

### Adding Device Linking

Device linking lets users share their inbox across multiple devices.

#### Requirements

- iOS 15.0+ / macOS 12.0+

#### Generate QR Code (Source Device)

```swift
// Generate link token
let response = try await CutiE.shared.initiateLinkToken()
let qrData = response.linkToken  // Encode as QR code

// Poll for confirmation
let status = try await CutiE.shared.checkLinkStatus(token: response.linkToken)
if status.status == .confirmed {
    print("Device linked!")
}
```

#### Scan and Confirm (Target Device)

```swift
// After scanning QR code
let result = try await CutiE.shared.confirmLink(
    token: scannedToken,
    deviceName: UIDevice.current.name
)
```

#### Manage Devices

```swift
// List linked devices
let devices = try await CutiE.shared.getLinkedDevices()

// Unlink a device
try await CutiE.shared.unlinkDevice(deviceId)
```

---

## Troubleshooting

### "CutiE is not configured"

**Error**: `CutiEError.notConfigured`

**Solution**: Call `configure()` before using any SDK methods:

```swift
// In AppDelegate.didFinishLaunching or App.init
CutiE.shared.configure(appId: "your_app_id")
```

### "Invalid API key" after migration

**Error**: `CutiEError.invalidAPIKey`

**Solution**: This shouldn't happen with 1.0.102+. Make sure you've:
1. Updated to 1.0.102 or later
2. Using `configure(appId:)` instead of `configure(apiKey:appId:)`

### Push notifications not working

1. **Check capability**: Xcode > Target > Signing & Capabilities > Push Notifications
2. **Check APNs key**: Admin dashboard has Key ID, Team ID, and .p8 contents
3. **Real device**: Push doesn't work in simulator
4. **Permission granted**: User must allow notifications

### App Attest fails silently

App Attest requires:
- iOS 14+ / macOS 11+
- Real device (not simulator)
- Valid App ID in Apple Developer Portal

The SDK falls back gracefully - check `isSupported` to verify availability.

### Device token validation fails

If `registerToken()` returns `.invalidPushToken`:
- Ensure you're passing the hex string, not raw `Data`
- Token should be 64 characters for standard APNs
- Only hex characters (0-9, a-f) allowed

```swift
// Convert Data to hex string correctly
let token = deviceToken.map { String(format: "%02x", $0) }.joined()
```

---

## Version History

| Version | Key Changes |
|---------|-------------|
| 2.1.0   | Deep-link navigation, public device linking API |
| 2.0.0   | **SubscriptionManager removed** (breaking change) |
| 1.0.104 | Push token validation, input sanitization |
| 1.0.103 | DocC documentation, CI improvements |
| 1.0.102 | **API key removal**, anonymous device registration |
| 1.0.101 | Documentation updates |
| 1.0.100 | GitHub Actions CI, Dependabot |
| 1.0.97  | Initial release with full feature set |

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.
