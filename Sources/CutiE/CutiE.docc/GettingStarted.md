# Getting Started with CutiE

Learn how to integrate CutiE SDK into your iOS app.

## Overview

This guide walks you through the basic setup and configuration of the CutiE SDK.

### Requirements

- iOS 14.0+ (iOS 15.0+ for async/await APIs and Inbox UI)
- Xcode 14.0+
- Swift 5.7+

### Installation

Add CutiE to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/cuti-e/ios-sdk.git", from: "1.0.0")
]
```

### Configuration

Configure the SDK early in your app's lifecycle, typically in your `App` struct or `AppDelegate`:

```swift
import SwiftUI
import CutiE

@main
struct MyApp: App {
    init() {
        // Configure with your App ID from the Cuti-E dashboard
        CutiE.shared.configure(appId: "app_your_app_id")

        // Optionally set user information
        CutiE.shared.setUserId("user_123")
        CutiE.shared.setUserName("John D.")

        // Set app metadata for better context
        CutiE.shared.setAppMetadata(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Enhanced Security with App Attest

For enhanced security, enable Apple App Attest to cryptographically verify requests:

```swift
CutiE.shared.configure(
    appId: "app_your_app_id",
    useAppAttest: true
)
```

> Note: App Attest requires iOS 14+ and is not available on simulators.

## Topics

### Next Steps

- <doc:CreatingConversations>
- <doc:PushNotifications>
