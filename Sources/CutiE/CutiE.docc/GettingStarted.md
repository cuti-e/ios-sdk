# Getting Started with Cuti-E

Set up Cuti-E in your iOS app in minutes.

## Overview

This guide walks you through adding Cuti-E to your app, configuring it with your credentials, and showing the feedback interface to users.

## Prerequisites

- iOS 15.0+ / macOS 12.0+
- Xcode 15.0+
- A Cuti-E account with API credentials

## Step 1: Add the Package

Add Cuti-E using Swift Package Manager in Xcode:

1. File → Add Package Dependencies
2. Enter: `https://github.com/cuti-e/ios-sdk`
3. Select version 1.0.0 or later

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/cuti-e/ios-sdk", from: "1.0.0")
]
```

## Step 2: Configure the SDK

Initialize Cuti-E when your app launches:

```swift
import CutiE

@main
struct MyApp: App {
    init() {
        CutiE.shared.configure(
            apiKey: "your-api-key",
            appID: "your-app-id"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

> Important: Never commit your API key to source control. Use environment variables or a secrets manager.

## Step 3: Show the Feedback View

Present ``CutiEFeedbackView`` when users want to send feedback:

```swift
struct SettingsView: View {
    @State private var showFeedback = false

    var body: some View {
        List {
            Button("Send Feedback") {
                showFeedback = true
            }
        }
        .sheet(isPresented: $showFeedback) {
            CutiEFeedbackView()
        }
    }
}
```

## Step 4: Enable Push Notifications (Optional)

To receive responses from your mascot character:

```swift
// In your AppDelegate or App init
CutiE.shared.pushNotifications.registerForRemoteNotifications()

// Handle device token
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    CutiE.shared.pushNotifications.setDeviceToken(deviceToken)
}
```

## Next Steps

- Learn about ``CutiEInboxView`` for showing message history
- Set up ``CutiESubscriptionManager`` for premium features
- Customize the character appearance in your admin dashboard
