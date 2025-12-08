# GitHub Copilot Instructions for Cuti-E iOS SDK

This file provides guidance for GitHub Copilot code review and code completion in this repository.

## Project Overview

**Cuti-E iOS SDK** enables character-driven feedback in iOS apps. Developers integrate this SDK to add feedback forms, conversation inbox, and push notifications.

**Package:** Swift Package Manager
**Minimum iOS:** 15.0+ (Inbox), 13.0+ (Core)
**Repository:** https://github.com/cuti-e/ios-sdk (public)

## Code Review Focus Areas

### Public API Design (Critical)
- All public types MUST have documentation comments
- Maintain backward compatibility - no breaking changes in minor versions
- Use `@available` annotations for iOS version-specific APIs
- Prefer completion handlers for broad compatibility, add async/await overloads

### Security
- Store device credentials in Keychain, never UserDefaults
- Validate server responses before processing
- Use App Attest when available (iOS 14+)
- Never log sensitive data (tokens, user IDs)

### SDK Architecture
```swift
// Main entry point is singleton
CutiE.shared.configure(appId: "...")
CutiE.shared.createConversation(...)

// Sub-managers for specific features
CutiE.shared.pushNotifications.requestPermission()
CutiE.shared.appAttest.isSupported
```

### Error Handling
```swift
// All errors must use CutiEError enum
public enum CutiEError: Error {
    case notConfigured
    case invalidAPIKey
    case networkError(Error)
    case serverError(Int, String)
    case decodingError
    case invalidRequest
}
```

## API Patterns

### Completion Handler Pattern (iOS 13+)
```swift
public func createConversation(
    category: ConversationCategory,
    message: String,
    completion: @escaping (Result<String, CutiEError>) -> Void
)
```

### Async/Await Pattern (iOS 15+)
```swift
@available(iOS 15.0, *)
public func createConversation(
    category: ConversationCategory,
    message: String
) async throws -> String
```

### SwiftUI Integration
```swift
// Provide SwiftUI views for easy integration
public struct CutiEFeedbackView: View { ... }
public struct CutiEInboxView: View { ... }
```

## Testing Requirements

### Before Creating PRs
```bash
# Build for iOS
xcodebuild build \
  -scheme CutiE \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -skipPackagePluginValidation

# Build for macOS (if supported)
xcodebuild build \
  -scheme CutiE \
  -destination 'platform=macOS'

# Build documentation
xcodebuild docbuild \
  -scheme CutiE \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath .build
```

## Common Pitfalls

- **Breaking changes**: Major version bump required for any public API changes
- **iOS version gates**: Use `@available` and `#available` for version-specific code
- **Thread safety**: All callbacks must dispatch to main queue
- **Memory leaks**: Use `[weak self]` in closures that capture self

## File Organization

```
ios-sdk/
├── Sources/CutiE/
│   ├── CutiE.swift           # Main SDK entry point
│   ├── Models/               # Public data models
│   ├── Services/             # Internal services
│   ├── Views/                # SwiftUI views
│   └── Utilities/            # Helper functions
├── Tests/CutiETests/
└── Package.swift
```

## Documentation Requirements

### DocC Comments
```swift
/// Creates a new feedback conversation.
///
/// Use this method to programmatically create a conversation without showing the feedback form.
///
/// - Parameters:
///   - category: The type of feedback (bug, feature, question, etc.)
///   - message: The initial message content
/// - Returns: The conversation ID on success
/// - Throws: `CutiEError` if the request fails
public func createConversation(...) async throws -> String
```

## Code Style

- Use Swift naming conventions (camelCase for methods/properties)
- Prefer value types (struct) over reference types (class) when possible
- Use `final` for classes that shouldn't be subclassed
- Keep public API surface minimal - mark internal types as `internal`
- Add `// MARK:` comments to organize code sections
