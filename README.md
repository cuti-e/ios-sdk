# Cuti-E iOS SDK

Character-driven feedback platform for iOS apps. Make customer support delightful and on-brand.

## Features

- 📱 **Easy Integration** - Add feedback to your iOS app in minutes
- 💬 **Conversations** - Two-way communication with your users
- 🔔 **Push Notifications** - Real-time notifications for responses
- 🎨 **SwiftUI & UIKit** - Works with both modern and legacy codebases
- 🔒 **Privacy-First** - User data stays on your infrastructure
- ⚡️ **Lightweight** - Minimal dependencies, small footprint

## Installation

### Swift Package Manager

Add Cuti-E to your project using Xcode:

1. File → Add Package Dependencies...
2. Enter the repository URL: `https://github.com/cuti-e/ios-sdk`
3. Select version or branch
4. Add to your target

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/cuti-e/ios-sdk.git", from: "1.0.75")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["CutiE"]
    )
]
```

## Getting Your Credentials

Before integrating the SDK, you'll need an **API Key** and **App ID** from the Cuti-E admin dashboard.

### 1. Get Your API Key

1. Go to [admin.cuti-e.com](https://admin.cuti-e.com)
2. Sign in or create an account
3. Navigate to **Settings** in the sidebar
4. Copy your **API Key** from the API Keys section

### 2. Create an App ID

1. In the admin dashboard, go to **Settings > Apps**
2. Click **Add App**
3. Enter your app's name and bundle identifier (e.g., `com.yourcompany.yourapp`)
4. Copy the generated **App ID**

> **Tip:** Use the sandbox API for development: `https://cutie-worker-sandbox.invotekas.workers.dev`

## Quick Start

### 1. Configure Cuti-E

In your `AppDelegate` or `@main` App struct:

```swift
import CutiE

// In AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Configure with your API key and App ID from the admin dashboard
    CutiE.shared.configure(
        apiKey: "your_api_key_here",
        appId: "your_app_id_here"  // Create in Settings → Apps
    )

    // For testing, use the sandbox environment:
    // CutiE.shared.configure(
    //     apiKey: "your_api_key",
    //     appId: "your_app_id",
    //     apiURL: "https://cutie-worker-sandbox.invotekas.workers.dev"
    // )

    return true
}
```

### Optional: Set User ID

Track feedback by user for better support context:

```swift
// Set user ID to associate feedback with a specific user
CutiE.shared.setUserId("user123")

// Or set app metadata
CutiE.shared.setAppMetadata(version: "1.2.0", build: "42")
```

### 2. Show Feedback Form (SwiftUI)

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

### 3. Create Conversation Programmatically

```swift
import CutiE

CutiE.shared.createConversation(
    category: .bug,
    message: "The app crashes when I tap the save button",
    title: "Crash on Save"
) { result in
    switch result {
    case .success(let conversationId):
        print("Created conversation: \(conversationId)")
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

## In-app Inbox (iOS 15+)

Let users view their feedback conversations and admin replies directly in your app.

### Show Inbox

Present the inbox modally:

```swift
// From any view controller
CutiE.shared.showInbox()

// Or from a specific view controller
CutiE.shared.showInbox(from: self)
```

### SwiftUI Integration

```swift
import SwiftUI
import CutiE

struct SettingsView: View {
    @State private var showInbox = false

    var body: some View {
        List {
            Button("My Feedback") {
                showInbox = true
            }
        }
        .sheet(isPresented: $showInbox) {
            CutiEInboxView()
        }
    }
}
```

### Async/Await API (iOS 15+)

```swift
// Get all conversations
let conversations = try await CutiE.shared.getConversations()

// Get single conversation with messages
let conversation = try await CutiE.shared.getConversation(id: "conv_abc123")

// Send a reply
let message = try await CutiE.shared.sendMessage(
    conversationId: "conv_abc123",
    message: "Thanks for the help!"
)
```

## Push Notifications

Enable push notifications to notify users when they receive responses to their feedback.

#### 1. Request Permission

In your app's initialization (e.g., `AppDelegate` or `@main` App struct):

```swift
import CutiE

// Request permission (iOS 10+)
CutiE.shared.pushNotifications.requestPermission { granted in
    print("Push notifications \(granted ? "enabled" : "denied")")
}

// Or using async/await (iOS 15+)
let granted = await CutiE.shared.pushNotifications.requestPermission()
```

#### 2. Register Device Token

In your `AppDelegate`:

```swift
import CutiE

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass the token to CutiE
        CutiE.shared.pushNotifications.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CutiE.shared.pushNotifications.didFailToRegisterForRemoteNotifications(withError: error)
    }
}
```

#### 3. Handle Notifications (Optional)

Implement the delegate to respond to notifications:

```swift
import CutiE

class MyNotificationHandler: CutiEPushNotificationDelegate {

    init() {
        CutiE.shared.pushNotifications.delegate = self
    }

    func cutiEDidReceiveMessage(conversationId: String, messagePreview: String?) {
        // New message received - update badge, show in-app notification, etc.
        print("New message in conversation: \(conversationId)")
    }

    func cutiEShouldOpenConversation(conversationId: String) {
        // User tapped notification - navigate to conversation
        print("Open conversation: \(conversationId)")
    }
}
```

#### 4. Forward Notifications to CutiE

In your `UNUserNotificationCenterDelegate`:

```swift
import UserNotifications
import CutiE

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Handle foreground notification
        let userInfo = notification.request.content.userInfo
        CutiE.shared.pushNotifications.handleNotification(userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        CutiE.shared.pushNotifications.handleNotificationTap(userInfo)
        completionHandler()
    }
}
```

#### 5. Check if Notification is from CutiE

```swift
let userInfo = notification.request.content.userInfo
if CutiE.shared.pushNotifications.isCutiENotification(userInfo) {
    // This is a CutiE notification
}
```

## Models

### Conversation

```swift
public struct Conversation {
    let id: String
    let title: String?
    let category: ConversationCategory
    let status: ConversationStatus
    let priority: ConversationPriority
    let messageCount: Int
    let messages: [Message]?
    let tags: [Tag]?
    let createdAt: Int64
    let updatedAt: Int64
}
```

### Message

```swift
public struct Message {
    let id: String
    let conversationID: String
    let senderType: SenderType  // .user, .admin, .system
    let senderName: String
    let message: String
    let isInternalNote: Bool
    let createdAt: Int64
}
```

### Conversation Category

```swift
public enum ConversationCategory: String {
    case bug           // 🐛 Bug Report
    case feature       // ✨ Feature Request
    case question      // ❓ Question
    case feedback      // 💬 Feedback
    case other         // 📝 Other
}
```

### Conversation Status

```swift
public enum ConversationStatus: String {
    case open
    case inProgress
    case waitingUser
    case waitingAdmin
    case resolved
    case closed
}
```

## Error Handling

```swift
CutiE.shared.createConversation(...) { result in
    switch result {
    case .success(let conversationId):
        // Handle success - conversationId is a String
    case .failure(let error):
        switch error {
        case .notConfigured:
            print("SDK not configured. Call CutiE.shared.configure() first")
        case .invalidAPIKey:
            print("Invalid API key")
        case .networkError(let underlyingError):
            print("Network error: \(underlyingError)")
        case .serverError(let code, let message):
            print("Server error (\(code)): \(message)")
        case .decodingError:
            print("Failed to decode response")
        case .invalidRequest:
            print("Invalid request")
        }
    }
}
```

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 15.0+

## License

MIT License - See LICENSE file for details

## Support

- 📧 Email: support@cuti-e.com
- 🌐 Website: https://cuti-e.com
- 📚 Docs: https://cuti-e.com/docs/

---

Made with ❤️ by the Cuti-E team
