# ``CutiE``

Character-driven feedback platform for iOS apps. Make customer support delightful and on-brand.

## Overview

Cuti-E SDK provides a complete solution for collecting and managing user feedback in your iOS app. It features a customizable feedback form, an in-app inbox for two-way communication, and push notification support.

### Features

- **Easy Integration** - Add feedback to your iOS app in minutes
- **Conversations** - Two-way communication with your users
- **Push Notifications** - Real-time notifications for responses
- **SwiftUI & UIKit** - Works with both modern and legacy codebases
- **Privacy-First** - User data stays on your infrastructure
- **Lightweight** - Minimal dependencies, small footprint

## Getting Started

### Configure the SDK

In your `AppDelegate` or `@main` App struct:

```swift
import CutiE

CutiE.shared.configure(appId: "your_app_id")
```

Get your App ID from the [Cuti-E Admin Dashboard](https://admin.cuti-e.com) under Settings > Apps.

### Show Feedback Form

```swift
import SwiftUI
import CutiE

struct ContentView: View {
    @State private var showFeedback = false

    var body: some View {
        Button("Send Feedback") {
            showFeedback = true
        }
        .sheet(isPresented: $showFeedback) {
            CutiEFeedbackView { conversationId in
                print("Feedback submitted: \(conversationId)")
            }
        }
    }
}
```

### Show In-App Inbox

```swift
// Present inbox modally
CutiE.shared.showInbox()

// Or use SwiftUI sheet
.sheet(isPresented: $showInbox) {
    CutiEInboxView()
}
```

## Topics

### Essentials

- ``CutiE``
- ``CutiEConfiguration``
- ``CutiEError``

### Feedback UI

- ``CutiEFeedbackView``
- ``CutiEInboxView``

### Push Notifications

- ``CutiEPushNotifications``
- ``CutiEPushNotificationDelegate``

### Models

- ``Conversation``
- ``Message``
- ``ConversationCategory``
- ``ConversationStatus``
- ``ConversationPriority``
- ``SenderType``
- ``Tag``

### Subscriptions (iOS 15+)

- ``CutiESubscriptionManager``
