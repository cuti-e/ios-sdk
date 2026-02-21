import XCTest
@testable import CutiE

final class DeviceContextTests: XCTestCase {

    // MARK: - DeviceContextField

    func testDeviceContextFieldAllCases() {
        let allCases = DeviceContextField.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.language))
        XCTAssertTrue(allCases.contains(.country))
        XCTAssertTrue(allCases.contains(.appVersion))
        XCTAssertTrue(allCases.contains(.osVersion))
        XCTAssertTrue(allCases.contains(.deviceModel))
    }

    // MARK: - DeviceContextConfig.enabledFields

    func testNoneConfigHasNoFields() {
        let config = DeviceContextConfig.none
        XCTAssertTrue(config.enabledFields.isEmpty)
    }

    func testMinimalConfigHasOnlyAppVersion() {
        let config = DeviceContextConfig.minimal
        XCTAssertEqual(config.enabledFields, [.appVersion])
    }

    func testStandardConfigHasFourFields() {
        let config = DeviceContextConfig.standard
        let expected: Set<DeviceContextField> = [.language, .country, .appVersion, .osVersion]
        XCTAssertEqual(config.enabledFields, expected)
    }

    func testAllConfigHasAllFields() {
        let config = DeviceContextConfig.all
        XCTAssertEqual(config.enabledFields, Set(DeviceContextField.allCases))
        XCTAssertEqual(config.enabledFields.count, 5)
    }

    func testCustomConfigWithSpecificFields() {
        let config = DeviceContextConfig.custom([.language, .country])
        XCTAssertEqual(config.enabledFields, [.language, .country])
    }

    func testCustomConfigWithEmptySet() {
        let config = DeviceContextConfig.custom([])
        XCTAssertTrue(config.enabledFields.isEmpty)
    }

    func testCustomConfigWithSingleField() {
        let config = DeviceContextConfig.custom([.osVersion])
        XCTAssertEqual(config.enabledFields, [.osVersion])
    }

    // MARK: - CutiEConfiguration.deviceContextPayload

    func testPayloadWithNoneContextIsEmpty() {
        let config = CutiEConfiguration(
            apiKey: nil, apiURL: "https://test.com", deviceID: "dev1",
            appId: "app1", deviceContext: .none
        )
        let payload = config.deviceContextPayload()
        XCTAssertTrue(payload.isEmpty)
    }

    func testPayloadWithLanguageFieldIncludesLanguage() {
        let config = CutiEConfiguration(
            apiKey: nil, apiURL: "https://test.com", deviceID: "dev1",
            appId: "app1", deviceContext: .custom([.language])
        )
        let payload = config.deviceContextPayload()
        // Language should be present (value depends on test runner locale)
        XCTAssertNotNil(payload["language"])
        XCTAssertFalse(payload["language"]!.isEmpty)
    }

    func testPayloadWithCountryFieldIncludesCountry() {
        let config = CutiEConfiguration(
            apiKey: nil, apiURL: "https://test.com", deviceID: "dev1",
            appId: "app1", deviceContext: .custom([.country])
        )
        let payload = config.deviceContextPayload()
        XCTAssertNotNil(payload["country"])
    }

    func testPayloadWithAppVersionUsesConfiguredVersion() {
        let config = CutiEConfiguration(
            apiKey: nil, apiURL: "https://test.com", deviceID: "dev1",
            appId: "app1", deviceContext: .custom([.appVersion])
        )
        config.appVersion = "2.5.0"
        let payload = config.deviceContextPayload()
        XCTAssertEqual(payload["app_version"], "2.5.0")
    }

    func testPayloadExcludesDisabledFields() {
        let config = CutiEConfiguration(
            apiKey: nil, apiURL: "https://test.com", deviceID: "dev1",
            appId: "app1", deviceContext: .custom([.language])
        )
        let payload = config.deviceContextPayload()
        XCTAssertNil(payload["country"])
        XCTAssertNil(payload["app_version"])
        XCTAssertNil(payload["os_version"])
        XCTAssertNil(payload["device_model"])
    }

    func testStandardPayloadIncludesExpectedKeys() {
        let config = CutiEConfiguration(
            apiKey: nil, apiURL: "https://test.com", deviceID: "dev1",
            appId: "app1", deviceContext: .standard
        )
        config.appVersion = "1.0.0"
        let payload = config.deviceContextPayload()
        XCTAssertNotNil(payload["language"])
        XCTAssertNotNil(payload["country"])
        XCTAssertEqual(payload["app_version"], "1.0.0")
        // os_version and device_model are only on iOS (UIKit), not macOS test runner
        #if os(iOS)
        XCTAssertNotNil(payload["os_version"])
        #endif
    }

    // MARK: - Configuration default

    func testDefaultDeviceContextIsNone() {
        let config = CutiEConfiguration(
            apiKey: nil, apiURL: "https://test.com", deviceID: "dev1",
            appId: "app1"
        )
        XCTAssertTrue(config.deviceContext.enabledFields.isEmpty)
        XCTAssertTrue(config.deviceContextPayload().isEmpty)
    }
}
