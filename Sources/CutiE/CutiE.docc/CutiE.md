# ``CutiE``

The official iOS SDK for integrating Cuti-E feedback and support into your app.

## Overview

CutiE SDK provides a complete solution for collecting user feedback, managing support conversations, and handling in-app subscriptions. The SDK offers both completion handler and async/await APIs for flexibility.

### Getting Started

Configure the SDK in your app's launch sequence:

```swift
import CutiE

// In your App or AppDelegate
CutiE.shared.configure(appId: "your_app_id")
```

### Creating Feedback

Users can submit feedback through conversations:

```swift
CutiE.shared.createConversation(
    category: .feedback,
    message: "Great app!"
) { result in
    switch result {
    case .success(let conversationId):
        print("Created conversation: \(conversationId)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Displaying the Inbox

Show the built-in inbox UI for users to view their conversations:

```swift
if #available(iOS 15.0, *) {
    CutiE.shared.showInbox()
}
```

## Topics

### Essentials

- ``CutiE``
- ``CutiEConfiguration``
- ``CutiEError``

### Conversations

- ``Conversation``
- ``ConversationCategory``
- ``Message``

### Subscriptions

- ``CutiESubscriptionManager``
- ``SubscriptionTier``
- ``SubscriptionStatus``

### Security

- ``CutiEAppAttest``
- ``AppAttestError``

### Push Notifications

- ``CutiEPushNotifications``
