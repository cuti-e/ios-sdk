# Changelog

All notable changes to the CutiE iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.104] - 2025-12-15

### Changed
- CI: Use self-hosted Linux runners for faster builds
- CI: Bump actions/github-script from 7 to 8
- CI: Bump actions/checkout from 4 to 6

## [1.0.103] - 2025-12-06

### Added
- App Attest documentation
- Device Linking documentation
- DocC documentation for public APIs

### Changed
- CI: Migrate to self-hosted macOS runner
- CI: Add auto-merge workflow for Dependabot PRs

### Fixed
- CI: Add checks:read permission to auto-merge workflow

## [1.0.102] - 2025-11-28

### Added
- Anonymous device registration - API key no longer required for basic usage

### Fixed
- Add diagnostic logging for 401 debugging
- Auto-retry on 401 when device token is invalid
- Add emoji property to ConversationCategory

## [1.0.101] - 2025-11-25

### Changed
- Updated README for anonymous device registration flow

## [1.0.100] - 2025-11-20

### Added
- DocC documentation catalog

### Changed
- Add GitHub Actions CI workflow
- Add Dependabot configuration

## [1.0.97] - 2025-11-15

### Added
- Initial public release
- Feedback submission with attachments
- Conversation management
- Push notification support
- App Attest integration
- Certificate pinning
- Subscription management with StoreKit 2

[1.0.104]: https://github.com/cuti-e/ios-sdk/compare/1.0.103...1.0.104
[1.0.103]: https://github.com/cuti-e/ios-sdk/compare/1.0.102...1.0.103
[1.0.102]: https://github.com/cuti-e/ios-sdk/compare/1.0.101...1.0.102
[1.0.101]: https://github.com/cuti-e/ios-sdk/compare/1.0.100...1.0.101
[1.0.100]: https://github.com/cuti-e/ios-sdk/compare/1.0.97...1.0.100
[1.0.97]: https://github.com/cuti-e/ios-sdk/releases/tag/1.0.97
