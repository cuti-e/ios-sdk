# Migration Guide

This guide helps you migrate between versions of the CutiE iOS SDK.

## Table of Contents

- [Migrating to 1.0.102+ (API Key Removal)](#migrating-to-10102-api-key-removal)
- [Migrating to 1.0.104+ (Push Token Validation)](#migrating-to-10104-push-token-validation)
- [Adding Optional Features](#adding-optional-features)
  - [App Attest](#adding-app-attest)
  - [Push Notifications](#adding-push-notifications)
  - [Device Linking](#adding-device-linking)
- [Troubleshooting](#troubleshooting)

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
let response = try await CutiE.shared.apiClient?.initiateLinkToken()
let qrData = response?.linkToken  // Encode as QR code

// Poll for confirmation
let status = try await CutiE.shared.apiClient?.checkLinkStatus(token: token)
if status?.status == .confirmed {
    print("Device linked!")
}
```

#### Scan and Confirm (Target Device)

```swift
// After scanning QR code
let result = try await CutiE.shared.apiClient?.confirmLink(
    token: scannedToken,
    deviceName: UIDevice.current.name
)
```

#### Manage Devices

```swift
// List linked devices
let devices = try await CutiE.shared.apiClient?.getLinkedDevices()

// Unlink a device
try await CutiE.shared.apiClient?.unlinkDevice(deviceId)
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
| 1.0.104 | Push token validation, input sanitization |
| 1.0.103 | DocC documentation, CI improvements |
| 1.0.102 | **API key removal**, anonymous device registration |
| 1.0.101 | Documentation updates |
| 1.0.100 | GitHub Actions CI, Dependabot |
| 1.0.97  | Initial release with full feature set |

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.
