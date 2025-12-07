import XCTest
@testable import CutiE

final class DeviceLinkingTests: XCTestCase {

    // MARK: - LinkTokenResponse Tests

    func testLinkTokenResponseDecoding() throws {
        let json = """
        {
            "link_token": "lt_abc123",
            "expires_at": 1700000000000,
            "expires_in": 300,
            "has_existing_group": false
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkTokenResponse.self, from: json)

        XCTAssertEqual(response.linkToken, "lt_abc123")
        XCTAssertEqual(response.expiresAt, 1700000000000)
        XCTAssertEqual(response.expiresIn, 300)
        XCTAssertFalse(response.hasExistingGroup)
    }

    func testLinkTokenResponseWithExistingGroup() throws {
        let json = """
        {
            "link_token": "lt_def456",
            "expires_at": 1700000000000,
            "expires_in": 300,
            "has_existing_group": true
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkTokenResponse.self, from: json)

        XCTAssertTrue(response.hasExistingGroup)
    }

    func testLinkTokenExpirationDate() {
        // Manually create the response to test date conversion
        let json = """
        {
            "link_token": "lt_test",
            "expires_at": 1700000000000,
            "expires_in": 300,
            "has_existing_group": false
        }
        """.data(using: .utf8)!

        let response = try! JSONDecoder().decode(LinkTokenResponse.self, from: json)
        let expectedDate = Date(timeIntervalSince1970: 1700000000)
        XCTAssertEqual(response.expirationDate, expectedDate)
    }

    // MARK: - LinkConfirmResponse Tests

    func testLinkConfirmResponseDecoding() throws {
        let json = """
        {
            "success": true,
            "group_id": "grp_xyz789",
            "message": "Device linked successfully"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkConfirmResponse.self, from: json)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.groupId, "grp_xyz789")
        XCTAssertEqual(response.message, "Device linked successfully")
    }

    func testLinkConfirmResponseFailure() throws {
        let json = """
        {
            "success": false,
            "group_id": "",
            "message": "Token expired"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkConfirmResponse.self, from: json)

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.message, "Token expired")
    }

    // MARK: - LinkTokenStatus Tests

    func testLinkTokenStatusRawValues() {
        XCTAssertEqual(LinkTokenStatus.pending.rawValue, "pending")
        XCTAssertEqual(LinkTokenStatus.confirmed.rawValue, "confirmed")
        XCTAssertEqual(LinkTokenStatus.expired.rawValue, "expired")
    }

    func testLinkTokenStatusDecoding() throws {
        let pending = try JSONDecoder().decode(LinkTokenStatus.self, from: "\"pending\"".data(using: .utf8)!)
        XCTAssertEqual(pending, .pending)

        let confirmed = try JSONDecoder().decode(LinkTokenStatus.self, from: "\"confirmed\"".data(using: .utf8)!)
        XCTAssertEqual(confirmed, .confirmed)

        let expired = try JSONDecoder().decode(LinkTokenStatus.self, from: "\"expired\"".data(using: .utf8)!)
        XCTAssertEqual(expired, .expired)
    }

    // MARK: - LinkStatusResponse Tests

    func testLinkStatusResponsePending() throws {
        let json = """
        {
            "status": "pending",
            "link_token": "lt_abc123",
            "expires_at": 1700000000000
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkStatusResponse.self, from: json)

        XCTAssertEqual(response.status, .pending)
        XCTAssertEqual(response.linkToken, "lt_abc123")
        XCTAssertNil(response.groupId)
        XCTAssertNil(response.targetDeviceName)
        XCTAssertNil(response.confirmedAt)
        XCTAssertEqual(response.expiresAt, 1700000000000)
    }

    func testLinkStatusResponseConfirmed() throws {
        let json = """
        {
            "status": "confirmed",
            "link_token": "lt_abc123",
            "group_id": "grp_xyz",
            "target_device_name": "John's iPad",
            "confirmed_at": 1700000050000
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkStatusResponse.self, from: json)

        XCTAssertEqual(response.status, .confirmed)
        XCTAssertEqual(response.groupId, "grp_xyz")
        XCTAssertEqual(response.targetDeviceName, "John's iPad")
        XCTAssertEqual(response.confirmedAt, 1700000050000)
    }

    func testLinkStatusResponseExpired() throws {
        let json = """
        {
            "status": "expired",
            "link_token": "lt_abc123"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkStatusResponse.self, from: json)

        XCTAssertEqual(response.status, .expired)
    }

    // MARK: - LinkedDevice Tests

    func testLinkedDeviceDecoding() throws {
        let json = """
        {
            "device_id": "device_abc123",
            "device_name": "John's iPhone",
            "joined_at": 1700000000000,
            "is_primary": true,
            "is_current": true
        }
        """.data(using: .utf8)!

        let device = try JSONDecoder().decode(LinkedDevice.self, from: json)

        XCTAssertEqual(device.deviceId, "device_abc123")
        XCTAssertEqual(device.deviceName, "John's iPhone")
        XCTAssertEqual(device.joinedAt, 1700000000000)
        XCTAssertTrue(device.isPrimary)
        XCTAssertTrue(device.isCurrent)
    }

    func testLinkedDeviceId() throws {
        let json = """
        {
            "device_id": "device_xyz",
            "device_name": "Test Device",
            "joined_at": 1700000000000,
            "is_primary": false,
            "is_current": false
        }
        """.data(using: .utf8)!

        let device = try JSONDecoder().decode(LinkedDevice.self, from: json)

        // Identifiable conformance: id should return deviceId
        XCTAssertEqual(device.id, "device_xyz")
        XCTAssertEqual(device.id, device.deviceId)
    }

    func testLinkedDeviceJoinedDate() throws {
        let json = """
        {
            "device_id": "device_test",
            "device_name": "Test",
            "joined_at": 1700000000000,
            "is_primary": false,
            "is_current": false
        }
        """.data(using: .utf8)!

        let device = try JSONDecoder().decode(LinkedDevice.self, from: json)
        let expectedDate = Date(timeIntervalSince1970: 1700000000)
        XCTAssertEqual(device.joinedDate, expectedDate)
    }

    func testLinkedDeviceSecondaryDevice() throws {
        let json = """
        {
            "device_id": "device_secondary",
            "device_name": "Secondary Device",
            "joined_at": 1700000000000,
            "is_primary": false,
            "is_current": true
        }
        """.data(using: .utf8)!

        let device = try JSONDecoder().decode(LinkedDevice.self, from: json)

        XCTAssertFalse(device.isPrimary)
        XCTAssertTrue(device.isCurrent)
    }

    // MARK: - LinkedDevicesResponse Tests

    func testLinkedDevicesResponseNotLinked() throws {
        let json = """
        {
            "linked": false,
            "devices": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkedDevicesResponse.self, from: json)

        XCTAssertFalse(response.linked)
        XCTAssertNil(response.groupId)
        XCTAssertTrue(response.devices.isEmpty)
    }

    func testLinkedDevicesResponseWithDevices() throws {
        let json = """
        {
            "linked": true,
            "group_id": "grp_123",
            "devices": [
                {
                    "device_id": "device_1",
                    "device_name": "iPhone",
                    "joined_at": 1700000000000,
                    "is_primary": true,
                    "is_current": true
                },
                {
                    "device_id": "device_2",
                    "device_name": "iPad",
                    "joined_at": 1700000050000,
                    "is_primary": false,
                    "is_current": false
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LinkedDevicesResponse.self, from: json)

        XCTAssertTrue(response.linked)
        XCTAssertEqual(response.groupId, "grp_123")
        XCTAssertEqual(response.devices.count, 2)
        XCTAssertEqual(response.devices[0].deviceName, "iPhone")
        XCTAssertEqual(response.devices[1].deviceName, "iPad")
    }
}
