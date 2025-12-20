# Cuti-E iOS SDK Architecture

This document describes the architecture of the Cuti-E iOS SDK using C4 diagrams.

## C4 Model Overview

The C4 model provides four levels of abstraction:
1. **Context** - System landscape and external dependencies
2. **Container** - High-level technology choices
3. **Component** - Internal structure of containers

---

## Level 1: System Context

Shows how the SDK fits into the broader ecosystem.

```mermaid
C4Context
    title System Context Diagram - Cuti-E iOS SDK

    Person(user, "App User", "End user of an iOS app with Cuti-E integration")
    Person(admin, "Support Admin", "Responds to feedback via Admin Dashboard")

    System_Boundary(app, "iOS Application") {
        System(iosApp, "iOS App", "Host application integrating Cuti-E SDK")
    }

    System(sdk, "Cuti-E iOS SDK", "Feedback SDK embedded in iOS apps")
    System_Ext(backend, "Cuti-E API", "Cloudflare Workers backend")
    System_Ext(adminDash, "Admin Dashboard", "Web app for managing feedback")
    System_Ext(apns, "Apple Push Notification service", "Delivers push notifications")
    System_Ext(appAttest, "Apple App Attest", "Device attestation service")

    Rel(user, iosApp, "Uses")
    Rel(iosApp, sdk, "Integrates")
    Rel(sdk, backend, "HTTPS/REST", "Conversations, messages, device linking")
    Rel(backend, apns, "Sends notifications")
    Rel(apns, iosApp, "Delivers push")
    Rel(sdk, appAttest, "Device attestation", "iOS 14+")
    Rel(admin, adminDash, "Manages feedback")
    Rel(adminDash, backend, "HTTPS/REST")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

### Simplified Context View

```mermaid
flowchart TB
    subgraph "iOS Device"
        App["iOS App"]
        SDK["Cuti-E SDK"]
        App --> SDK
    end

    subgraph "Apple Services"
        APNs["Apple Push Notifications"]
        AppAttest["App Attest Service"]
        Keychain["Keychain Services"]
    end

    subgraph "Cuti-E Platform"
        API["Cuti-E API<br/>(Cloudflare Workers)"]
        Admin["Admin Dashboard"]
    end

    SDK <-->|"HTTPS/REST"| API
    SDK <-->|"Device Attestation"| AppAttest
    SDK <-->|"Secure Storage"| Keychain
    API -->|"Push Notifications"| APNs
    APNs -->|"Deliver"| App
    Admin <-->|"Manage Feedback"| API
```

---

## Level 2: Container Diagram

Shows the SDK as a Swift Package with its main modules.

```mermaid
flowchart TB
    subgraph sdk["Cuti-E iOS SDK (Swift Package)"]
        direction TB

        subgraph public["Public API"]
            CutiE["CutiE<br/>(Main Entry Point)"]
            Views["SwiftUI Views<br/>FeedbackView, InboxView"]
            Models["Data Models<br/>Conversation, Message"]
        end

        subgraph internal["Internal Components"]
            APIClient["CutiEAPIClient<br/>(HTTP Client)"]
            Push["CutiEPushNotifications<br/>(APNs Handler)"]
            Attest["CutiEAppAttest<br/>(Device Verification)"]
            Pinning["CutiECertificatePinning<br/>(SSL Security)"]
            Subscriptions["CutiESubscriptionManager<br/>(StoreKit)"]
        end
    end

    subgraph external["External Dependencies"]
        Foundation["Foundation"]
        SwiftUI["SwiftUI"]
        DeviceCheck["DeviceCheck"]
        UserNotifications["UserNotifications"]
        Security["Security Framework"]
    end

    CutiE --> APIClient
    CutiE --> Push
    CutiE --> Attest
    Views --> CutiE
    APIClient --> Pinning
    APIClient --> Models

    sdk --> Foundation
    Views --> SwiftUI
    Attest --> DeviceCheck
    Push --> UserNotifications
    Pinning --> Security
```

---

## Level 3: Component Diagram

Shows the internal structure and relationships between SDK components.

```mermaid
flowchart TB
    subgraph "CutiE (Main Entry Point)"
        configure["configure(appId:)"]
        createConv["createConversation()"]
        getConvs["getConversations()"]
        showInbox["showInbox()"]
        setUser["setUserId()"]
    end

    subgraph "CutiEAPIClient"
        request["request()"]
        deviceToken["Device Token<br/>(Keychain)"]
        signature["Device Signature<br/>(SHA256)"]
    end

    subgraph "CutiEPushNotifications"
        reqPerm["requestPermission()"]
        regToken["registerToken()"]
        handleNotif["handleNotification()"]
        clearBadge["clearBadgeCount()"]
    end

    subgraph "CutiEAppAttest"
        attest["performAttestation()"]
        assert["generateAssertion()"]
        keyStore["Keychain Storage"]
    end

    subgraph "CutiECertificatePinning"
        validate["validateCertificateChain()"]
        spkiHash["SPKI SHA-256 Hashes"]
    end

    subgraph "Views (SwiftUI)"
        FeedbackView["CutiEFeedbackView"]
        InboxView["CutiEInboxView"]
        ConversationView["CutiEConversationView"]
    end

    subgraph "Models"
        Conversation
        Message
        Tag
        LinkedDevice
    end

    configure --> request
    createConv --> request
    getConvs --> request
    request --> validate
    request --> signature
    request --> deviceToken

    FeedbackView --> createConv
    InboxView --> getConvs
    ConversationView --> Message

    attest --> request
    regToken --> request

    showInbox --> InboxView
```

---

## Data Flow Diagrams

### Conversation Creation Flow

```mermaid
sequenceDiagram
    participant App as iOS App
    participant SDK as CutiE SDK
    participant Pin as Certificate Pinning
    participant API as Cuti-E API

    App->>SDK: createConversation(category, message)
    SDK->>SDK: Check configuration
    SDK->>SDK: Generate device signature
    SDK->>Pin: Create pinned URLSession
    SDK->>API: POST /v1/conversations
    API-->>SDK: { conversation_id, status }
    SDK-->>App: Result<String, CutiEError>
```

### Push Notification Flow

```mermaid
sequenceDiagram
    participant App as iOS App
    participant SDK as CutiE SDK
    participant APNs as Apple APNs
    participant API as Cuti-E API
    participant Admin as Admin Dashboard

    App->>SDK: requestPermission()
    SDK->>APNs: Register for notifications
    APNs-->>App: Device token
    App->>SDK: didRegisterForRemoteNotifications(token)
    SDK->>API: POST /v1/notifications/register

    Note over Admin,API: Admin replies to conversation

    API->>APNs: Send push notification
    APNs->>App: Deliver notification
    App->>SDK: handleNotification(userInfo)
    SDK->>SDK: Parse conversation_id
    SDK-->>App: Delegate callback
```

### App Attest Flow

```mermaid
sequenceDiagram
    participant App as iOS App
    participant SDK as CutiE SDK
    participant Enclave as Secure Enclave
    participant Apple as Apple App Attest
    participant API as Cuti-E API

    App->>SDK: configure(useAppAttest: true)
    SDK->>Enclave: Generate key pair
    Enclave-->>SDK: Key ID
    SDK->>API: POST /v1/device/attest/challenge
    API-->>SDK: { challenge }
    SDK->>Apple: attestKey(keyId, clientDataHash)
    Apple-->>SDK: Attestation object
    SDK->>API: POST /v1/device/attest
    API-->>SDK: { success: true }

    Note over SDK: Device is now attested

    SDK->>Enclave: generateAssertion(clientData)
    Enclave-->>SDK: Signed assertion
    SDK->>API: Request with X-App-Assertion header
```

### Device Linking Flow

```mermaid
sequenceDiagram
    participant Source as Source Device
    participant SDK1 as CutiE SDK
    participant API as Cuti-E API
    participant SDK2 as CutiE SDK
    participant Target as Target Device

    Source->>SDK1: initiateLinkToken()
    SDK1->>API: POST /v1/sdk/link/initiate
    API-->>SDK1: { link_token, expires_at }
    SDK1-->>Source: Display as QR code

    Target->>SDK2: Scan QR code
    SDK2->>API: POST /v1/sdk/link/confirm
    API-->>SDK2: { success, group_id }

    Source->>SDK1: checkLinkStatus(token)
    SDK1->>API: GET /v1/sdk/link/status/{token}
    API-->>SDK1: { status: "confirmed" }

    Note over Source,Target: Both devices now share inbox
```

---

## Security Architecture

```mermaid
flowchart TB
    subgraph "Transport Security"
        TLS["TLS 1.3"]
        Pin["Certificate Pinning<br/>(Google Trust Services)"]
    end

    subgraph "Device Authentication"
        DeviceID["Device ID<br/>(UserDefaults)"]
        DeviceToken["Device Token<br/>(Keychain)"]
        DeviceSecret["Device Secret<br/>(SHA-256)"]
    end

    subgraph "Enhanced Security (iOS 14+)"
        AppAttest["App Attest"]
        SecureEnclave["Secure Enclave"]
        Attestation["Attestation Key"]
        Assertion["Request Assertions"]
    end

    subgraph "API Security"
        Headers["X-App-ID<br/>X-Device-ID<br/>X-Device-Token"]
        Validation["Server-side Validation"]
    end

    TLS --> Pin
    Pin --> Headers
    DeviceID --> DeviceSecret
    DeviceToken --> Headers

    AppAttest --> SecureEnclave
    SecureEnclave --> Attestation
    Attestation --> Assertion
    Assertion --> Headers

    Headers --> Validation
```

---

## Module Dependencies

```mermaid
graph LR
    subgraph "Apple Frameworks"
        Foundation
        SwiftUI
        UIKit
        Security
        DeviceCheck
        UserNotifications
        CommonCrypto
    end

    subgraph "SDK Modules"
        CutiE
        APIClient
        Views
        Models
        Push
        Attest
        Pinning
    end

    CutiE --> Foundation
    CutiE --> APIClient
    CutiE --> Push
    CutiE --> Attest

    APIClient --> Foundation
    APIClient --> Security
    APIClient --> CommonCrypto
    APIClient --> Pinning
    APIClient --> Models

    Views --> SwiftUI
    Views --> CutiE
    Views --> Models

    Push --> Foundation
    Push --> UserNotifications
    Push --> UIKit

    Attest --> Foundation
    Attest --> DeviceCheck
    Attest --> Security
    Attest --> CommonCrypto

    Pinning --> Foundation
    Pinning --> Security
    Pinning --> CommonCrypto
```

---

## Platform Requirements

| Component | Minimum iOS | Minimum macOS | Notes |
|-----------|-------------|---------------|-------|
| Core SDK | 15.0 | 12.0 | Base functionality |
| Push Notifications | 10.0 | 10.14 | `UserNotifications` |
| App Attest | 14.0 | 11.0 | `DeviceCheck` |
| Async/Await APIs | 15.0 | 12.0 | Swift concurrency |
| SwiftUI Views | 15.0 | 12.0 | `CutiEInboxView`, etc. |

---

## File Structure

```
Sources/CutiE/
├── CutiE.swift                    # Main entry point, configuration
├── CutiEAPIClient.swift           # HTTP client, device auth
├── CutiEAppAttest.swift           # Apple App Attest integration
├── CutiECertificatePinning.swift  # SSL certificate pinning
├── CutiEFeedbackView.swift        # Feedback form (SwiftUI)
├── CutiEPushNotifications.swift   # APNs integration
├── CutiESubscriptionManager.swift # StoreKit subscriptions
├── Models.swift                   # Data models
└── Views/
    ├── CutiEInboxView.swift       # Conversation list
    └── CutiEConversationView.swift # Message thread
```
