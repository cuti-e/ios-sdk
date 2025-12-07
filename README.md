# Cuti-E iOS SDK

Character-driven feedback platform for iOS apps. Make customer support delightful and on-brand.

![Cuti-E SDK Banner](https://cuti-e.com/docs/images/sdk-banner-placeholder.png)

## Features

- 📱 **Easy Integration** - Add feedback to your iOS app in minutes
- 💬 **Conversations** - Two-way communication with your users
- 🔔 **Push Notifications** - Real-time notifications for responses
- 🎨 **SwiftUI & UIKit** - Works with both modern and legacy codebases
- 🔒 **Privacy-First** - User data stays on your infrastructure
- ⚡️ **Lightweight** - Minimal dependencies, small footprint
- 🔐 **App Attest** - Enhanced device verification using Apple's secure enclave (iOS 14+)
- 📲 **Device Linking** - Share conversation inbox across multiple devices via QR code

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
    .package(url: "https://github.com/cuti-e/ios-sdk.git", from: "1.0.103")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["CutiE"]
    )
]
```

## Getting Your App ID

Before integrating the SDK, you'll need an **App ID** from the Cuti-E admin dashboard.

### Create an App ID

1. Go to [admin.cuti-e.com](https://admin.cuti-e.com)
2. Sign in or create an account
3. Navigate to **Settings > Apps** in the sidebar
4. Click **Add App**
5. Enter your app's name and bundle identifier (e.g., `com.yourcompany.yourapp`)
6. Copy the generated **App ID**

> **Tip:** Use the sandbox API for development: `https://cutie-worker-sandbox.invotekas.workers.dev`

## Quick Start

### 1. Configure Cuti-E

In your `AppDelegate` or `@main` App struct:

```swift
import CutiE

// In AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Configure with your App ID from the admin dashboard
    CutiE.shared.configure(appId: "your_app_id_here")

    // For testing, use the sandbox environment:
    // CutiE.shared.configure(
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

<!-- TODO: Add screenshot -->
![Feedback Form](https://cuti-e.com/docs/images/feedback-form-placeholder.png)
*The feedback form allows users to submit bug reports, feature requests, and general feedback.*

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

<!-- TODO: Add screenshot -->
![In-app Inbox](https://cuti-e.com/docs/images/inbox-placeholder.png)
*The inbox shows all conversations and allows users to continue chatting with support.*

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

<!-- TODO: Add screenshot -->
![Push Notification](https://cuti-e.com/docs/images/push-notification-placeholder.png)
*Users receive push notifications when admins reply to their feedback.*

> **Important:** Push notifications require setup in **three places**: Xcode, Apple Developer Portal, and your code. Follow ALL steps below or notifications won't work.

---

### Prerequisites (Do These First!)

Before writing any code, you must complete these setup steps:

#### Step 1: Enable Push Notifications in Xcode

1. Open your project in Xcode
2. Click on your **project name** in the left sidebar (the blue icon at the top)
3. Select your **app target** (not the project)
4. Click the **"Signing & Capabilities"** tab
5. Click the **"+ Capability"** button (top left of the tab)
6. Search for **"Push Notifications"** and double-click it
7. You should now see "Push Notifications" listed under capabilities

<!-- TODO: Add screenshot -->
![Xcode Push Capability](https://cuti-e.com/docs/images/xcode-push-capability-placeholder.png)
*Adding the Push Notifications capability in Xcode.*

**What this does:** Creates the required entitlements file that tells iOS your app can receive push notifications.

> **Troubleshooting:** If you don't see the "+ Capability" button, make sure you have a valid Apple Developer account connected in Xcode → Settings → Accounts.

#### Step 2: Create an APNs Key in Apple Developer Portal

1. Go to [developer.apple.com](https://developer.apple.com) and sign in
2. Click **"Certificates, Identifiers & Profiles"**
3. In the left sidebar, click **"Keys"**
4. Click the **"+"** button to create a new key
5. Enter a name like **"CutiE Push Key"**
6. Check the box for **"Apple Push Notifications service (APNs)"**
7. Click **"Continue"**, then **"Register"**
8. **IMPORTANT:** Click **"Download"** to save the `.p8` file
   - ⚠️ You can only download this file ONCE! Save it somewhere safe!
9. Note down the **Key ID** shown on the page (e.g., `ABC123DEFG`)
10. Also note your **Team ID** - find it at [developer.apple.com/account](https://developer.apple.com/account) in the top right

**You now have:**
- A `.p8` key file (e.g., `AuthKey_ABC123DEFG.p8`)
- A Key ID (e.g., `ABC123DEFG`)
- Your Team ID (e.g., `ABCD1234EF`)

<!-- TODO: Add screenshot -->
![Apple Developer Keys](https://cuti-e.com/docs/images/apple-developer-keys-placeholder.png)
*Creating an APNs key in the Apple Developer Portal.*

#### Step 3: Configure APNs in Cuti-E Admin Dashboard

1. Go to [admin.cuti-e.com](https://admin.cuti-e.com) and sign in
2. Navigate to **Settings** in the sidebar
3. Scroll to the **"Push Notifications"** section
4. Enter your **Key ID** from Step 2
5. Enter your **Team ID** from Step 2
6. Open your `.p8` file in a text editor and copy the entire contents
7. Paste the key contents into the **"APNs Auth Key"** field
8. Click **Save**

<!-- TODO: Add screenshot -->
![Cuti-E Admin APNs Settings](https://cuti-e.com/docs/images/admin-apns-settings-placeholder.png)
*Configuring APNs credentials in the Cuti-E Admin Dashboard.*

**What this does:** Allows the Cuti-E backend to send push notifications to your app on your behalf.

---

### Code Integration

Now that the prerequisites are complete, add the code to your app:

#### Step 4: Request Permission (Required)

In your `AppDelegate` or `@main` App struct, request permission to send notifications:

```swift
import CutiE

// Request permission (iOS 10+)
CutiE.shared.pushNotifications.requestPermission { granted in
    if granted {
        print("✅ Push notifications enabled!")
    } else {
        print("❌ User denied push notifications")
    }
}

// Or using async/await (iOS 15+)
let granted = await CutiE.shared.pushNotifications.requestPermission()
```

> **When to call this:** Call this after the user has used your app a bit, not immediately on first launch. Users are more likely to allow notifications if they understand the value.

#### Step 5: Register Device Token (Required)

Add these methods to your `AppDelegate.swift`:

```swift
import UIKit
import CutiE

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Configure CutiE first
        CutiE.shared.configure(appId: "your_app_id")

        return true
    }

    // Called when Apple gives us a device token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Send the token to CutiE so we can send notifications to this device
        CutiE.shared.pushNotifications.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        print("✅ Device token registered with CutiE")
    }

    // Called if registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CutiE.shared.pushNotifications.didFailToRegisterForRemoteNotifications(withError: error)
        print("❌ Failed to register for push notifications: \(error)")
    }
}
```

**For SwiftUI apps:** If you're using SwiftUI with `@main`, you need to connect the AppDelegate:

```swift
import SwiftUI

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### Step 6: Handle Incoming Notifications (Required)

Add this to show notifications when the app is in the foreground and handle taps:

```swift
import UserNotifications
import CutiE

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Set up the delegate in didFinishLaunching
    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }

    // Called when a notification arrives while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        // Let CutiE handle it if it's a CutiE notification
        CutiE.shared.pushNotifications.handleNotification(userInfo)

        // Show the notification banner even when app is open
        completionHandler([.banner, .sound, .badge])
    }

    // Called when user taps on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Let CutiE handle the tap
        CutiE.shared.pushNotifications.handleNotificationTap(userInfo)

        completionHandler()
    }
}
```

Update your `didFinishLaunchingWithOptions` to set up the delegate:

```swift
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {

    // Set up notification delegate
    UNUserNotificationCenter.current().delegate = self

    // Configure CutiE
    CutiE.shared.configure(appId: "your_app_id")

    return true
}
```

---

### Step 7: Clear Badge Count (Recommended)

The app icon badge accumulates as notifications arrive. Clear it when your app becomes active:

```swift
import SwiftUI
import CutiE

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        // Clear badge when app opens or comes to foreground
                        CutiE.shared.pushNotifications.clearBadgeCount()
                    }
                }
        }
    }
}
```

---

### Optional: Custom Notification Handling

If you want to do something special when notifications arrive:

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

        // Example: Open the inbox and show this conversation
        CutiE.shared.showInbox()
    }
}
```

### Checking if a Notification is from CutiE

```swift
let userInfo = notification.request.content.userInfo
if CutiE.shared.pushNotifications.isCutiENotification(userInfo) {
    // This is a CutiE notification
}
```

---

### Testing Push Notifications

1. **You must use a real device** - Push notifications do NOT work in the iOS Simulator
2. Build and run on your device
3. Allow notifications when prompted
4. Submit feedback through your app
5. Reply to the feedback in the Cuti-E Admin dashboard
6. Within 1 minute, you should receive a push notification on your device

**Troubleshooting:**
- ❌ No notification? Check that all 3 prerequisites are complete
- ❌ "Failed to register"? Make sure Push Notifications capability is added in Xcode
- ❌ Still not working? Check the Cuti-E Admin dashboard logs for errors

## App Attest (iOS 14+)

App Attest provides enhanced device verification using Apple's secure enclave. When enabled, it cryptographically proves that API requests come from a legitimate copy of your app running on a real Apple device.

### Enable App Attest

```swift
// Enable during configuration
CutiE.shared.configure(
    appId: "your_app_id",
    useAppAttest: true  // Enable App Attest
)
```

### Check Attestation Status

```swift
// Check if App Attest is supported on this device
if CutiE.shared.appAttest.isSupported {
    print("App Attest is supported")
}

// Check if device has been attested
if CutiE.shared.appAttest.isAttested {
    print("Device is attested")
}
```

> **Note:** App Attest requires iOS 14+ and is not available on all devices (e.g., simulators). The SDK gracefully falls back to standard authentication when App Attest is unavailable.

## Device Linking (iOS 15+)

Device linking allows users to share their conversation inbox across multiple devices. For example, a user can link their iPad to their iPhone to see and respond to conversations from either device.

### Generate Link Token (Source Device)

```swift
// Generate a link token to display as QR code
let response = try await CutiE.shared.initiateLinkToken()
let qrCodeData = response.linkToken  // Display this as QR code

// Poll for link completion
let status = try await CutiE.shared.checkLinkStatus(token: response.linkToken)
if status.status == "linked" {
    print("Device linked successfully!")
}
```

### Confirm Link (Target Device)

```swift
// After scanning QR code, confirm the link
let result = try await CutiE.shared.confirmLink(
    token: scannedToken,
    deviceName: "My iPad"  // Optional device name
)
print("Linked to group: \(result.linkedDeviceId)")
```

### Manage Linked Devices

```swift
// Get all linked devices
let devices = try await CutiE.shared.getLinkedDevices()
for device in devices.devices {
    print("\(device.deviceName ?? "Unknown") - \(device.deviceId)")
}

// Unlink a device
try await CutiE.shared.unlinkDevice(deviceId)
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

- 📧 Email: <support@cuti-e.com>
- 🌐 Website: <https://cuti-e.com>
- 📚 Docs: <https://cuti-e.com/docs/>

---

Made with ❤️ by the Cuti-E team
