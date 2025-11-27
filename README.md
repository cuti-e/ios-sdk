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
2. Enter the repository URL: `https://github.com/Stig-Johnny/cutie`
3. Select "ios" folder as the package path
4. Select version or branch
5. Add to your target

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Stig-Johnny/cutie.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["CutiE"],
        path: "ios"
    )
]
```

## Quick Start

### 1. Configure Cuti-E

In your `AppDelegate` or `@main` App struct:

```swift
import CutiE

// In AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Configure with your API key from the admin dashboard
    CutiE.shared.configure(apiKey: "your_api_key_here")

    // For testing, use the sandbox environment:
    // CutiE.shared.configure(
    //     apiKey: "dfc651dc574cbddf88332b1acd2e5c2234110e993b2d338d1cb2be21df47c8b2",
    //     apiURL: "https://cutie-worker-sandbox.invotekas.workers.dev"
    // )

    return true
}
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
            CutiEFeedbackView { conversation in
                print("Feedback submitted: \(conversation.id)")
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
    case .success(let conversation):
        print("Created conversation: \(conversation.id)")
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

## Advanced Usage

### List Conversations

```swift
CutiE.shared.listConversations { result in
    switch result {
    case .success(let conversations):
        print("Found \(conversations.count) conversations")
        for conversation in conversations {
            print("- \(conversation.title ?? "Untitled") (\(conversation.status.displayName))")
        }
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

### Get Conversation with Messages

```swift
CutiE.shared.getConversation("conv_abc123") { result in
    switch result {
    case .success(let conversation):
        print("Conversation: \(conversation.title ?? "Untitled")")
        print("Messages: \(conversation.messages?.count ?? 0)")

        conversation.messages?.forEach { message in
            print("\(message.senderName): \(message.message)")
        }
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

### Send Message

```swift
CutiE.shared.sendMessage(
    "Thanks for the help!",
    in: "conv_abc123"
) { result in
    switch result {
    case .success(let message):
        print("Message sent: \(message.id)")
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

### Push Notifications

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
    case .success(let conversation):
        // Handle success
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
- 📚 Docs: https://docs.cuti-e.com

---

Made with ❤️ by the Cuti-E team
