# Changelog

All notable changes to the CutiE iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0](https://github.com/cuti-e/ios-sdk/compare/1.1.1...2.0.0) (2026-02-15)


### ⚠ BREAKING CHANGES

* remove CutiESubscriptionManager from SDK ([#69](https://github.com/cuti-e/ios-sdk/issues/69))

### Bug Fixes

* **ci:** install GNU tar for macOS Pages deployment ([#66](https://github.com/cuti-e/ios-sdk/issues/66)) ([7cb4965](https://github.com/cuti-e/ios-sdk/commit/7cb4965278907ddffd7e663b28288f23d8da7125))
* **ci:** trigger release-please after auto-merge ([#67](https://github.com/cuti-e/ios-sdk/issues/67)) ([5aadfb3](https://github.com/cuti-e/ios-sdk/commit/5aadfb3746a7e54605323d3212d7284a64fcf190))


### Code Refactoring

* remove CutiESubscriptionManager from SDK ([#69](https://github.com/cuti-e/ios-sdk/issues/69)) ([379f3e2](https://github.com/cuti-e/ios-sdk/commit/379f3e24c0a0e4502a0ff6a8ddc5ea3a75436c24))

## [1.1.1](https://github.com/cuti-e/ios-sdk/compare/1.1.0...1.1.1) (2026-02-14)


### Bug Fixes

* **release:** Sync sdkVersion with release-please manifest ([#59](https://github.com/cuti-e/ios-sdk/issues/59)) ([53cde7b](https://github.com/cuti-e/ios-sdk/commit/53cde7b363fccdf7c5cf03109f23fae19b3b2800)), closes [#55](https://github.com/cuti-e/ios-sdk/issues/55)

## [1.1.0](https://github.com/cuti-e/ios-sdk/compare/1.0.104...1.1.0) (2026-02-14)


### Features

* Add certificate pinning expiry monitoring ([#45](https://github.com/cuti-e/ios-sdk/issues/45)) ([c798eea](https://github.com/cuti-e/ios-sdk/commit/c798eea3cf336ff3d43d419a98ee90470ace47b5))
* Add SDK version header to all API requests ([#53](https://github.com/cuti-e/ios-sdk/issues/53)) ([7ea427c](https://github.com/cuti-e/ios-sdk/commit/7ea427c621e3072948557463b3e13c1134e65397))


### Bug Fixes

* Add HTTPS enforcement in configure() ([#36](https://github.com/cuti-e/ios-sdk/issues/36)) ([0160d5f](https://github.com/cuti-e/ios-sdk/commit/0160d5f7a7bf39b48acd8112fdecee78b984f761))
* **ci:** Add checks:read permission to auto-merge workflow ([#22](https://github.com/cuti-e/ios-sdk/issues/22)) ([723b7c8](https://github.com/cuti-e/ios-sdk/commit/723b7c857fdb2df28a17944caff0b47db0021b00))
* **ci:** Use generic simulator destination ([#35](https://github.com/cuti-e/ios-sdk/issues/35)) ([4467e23](https://github.com/cuti-e/ios-sdk/commit/4467e236614c02a464f65aaba11df87ef60fd1fd))
* **ci:** use macOS runner for release-please workflow ([#54](https://github.com/cuti-e/ios-sdk/issues/54)) ([67f456a](https://github.com/cuti-e/ios-sdk/commit/67f456a905024582b51edf824de76f8e8f737ba3))
* Replace print() with NSLog for consistent logging ([#33](https://github.com/cuti-e/ios-sdk/issues/33)) ([17e1f48](https://github.com/cuti-e/ios-sdk/commit/17e1f48387a381e10773f42f5113dfdc1c6dfa2b))
* Simplify pin-expiry-check workflow for Dependabot compatibility ([#48](https://github.com/cuti-e/ios-sdk/issues/48)) ([b7f4617](https://github.com/cuti-e/ios-sdk/commit/b7f461787c455c85e8f22fa53e015ee9329f42b2))
* Use self-hosted macOS runner for pin-expiry-check workflow ([#46](https://github.com/cuti-e/ios-sdk/issues/46)) ([07523ed](https://github.com/cuti-e/ios-sdk/commit/07523eddfa00fc18b2d7e69b95ca5b312a1ec3f9))

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

[1.0.104]: https://github.com/cuti-e/ios-sdk/compare/1.0.103...1.0.104
[1.0.103]: https://github.com/cuti-e/ios-sdk/compare/1.0.102...1.0.103
[1.0.102]: https://github.com/cuti-e/ios-sdk/compare/1.0.101...1.0.102
[1.0.101]: https://github.com/cuti-e/ios-sdk/compare/1.0.100...1.0.101
[1.0.100]: https://github.com/cuti-e/ios-sdk/compare/1.0.97...1.0.100
[1.0.97]: https://github.com/cuti-e/ios-sdk/releases/tag/1.0.97
