# ``CutiE``

Character-driven feedback SDK for iOS apps.

## Overview

Cuti-E brings friendly mascot characters to your app's feedback and support experience. Instead of boring forms, users interact with cute characters that make giving feedback feel personal and engaging.

### Features

- **Feedback Collection** - Collect user feedback through an engaging character interface
- **Push Notifications** - Send personalized messages from your mascot character
- **Subscription Management** - Handle in-app purchases with StoreKit 2
- **Real-time Updates** - Sync feedback status and responses instantly

## Getting Started

### Installation

Add Cuti-E to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/cuti-e/ios-sdk", from: "1.0.0")
]
```

### Configuration

Configure Cuti-E in your app's initialization:

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

### Showing the Feedback View

Present the feedback interface to your users:

```swift
import SwiftUI
import CutiE

struct SettingsView: View {
    @State private var showFeedback = false

    var body: some View {
        Button("Send Feedback") {
            showFeedback = true
        }
        .sheet(isPresented: $showFeedback) {
            CutiEFeedbackView()
        }
    }
}
```

## Topics

### Essentials

- ``CutiE``
- ``CutiEConfiguration``

### Views

- ``CutiEFeedbackView``
- ``CutiEInboxView``

### Push Notifications

- ``CutiEPushNotifications``

### Subscriptions

- ``CutiESubscriptionManager``
