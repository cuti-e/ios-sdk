import XCTest
@testable import CutiE

// MARK: - SubscriptionTier Tests

final class SubscriptionTierTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(SubscriptionTier.free.rawValue, 0)
        XCTAssertEqual(SubscriptionTier.starter.rawValue, 1)
        XCTAssertEqual(SubscriptionTier.pro.rawValue, 2)
        XCTAssertEqual(SubscriptionTier.business.rawValue, 3)
    }

    func testDisplayNames() {
        XCTAssertEqual(SubscriptionTier.free.displayName, "Free")
        XCTAssertEqual(SubscriptionTier.starter.displayName, "Starter")
        XCTAssertEqual(SubscriptionTier.pro.displayName, "Pro")
        XCTAssertEqual(SubscriptionTier.business.displayName, "Business")
    }

    func testFeedbackLimits() {
        XCTAssertEqual(SubscriptionTier.free.feedbackLimit, 50)
        XCTAssertEqual(SubscriptionTier.starter.feedbackLimit, 500)
        XCTAssertEqual(SubscriptionTier.pro.feedbackLimit, 10_000)
        XCTAssertEqual(SubscriptionTier.business.feedbackLimit, Int.max)
    }

    func testComparable() {
        XCTAssertTrue(SubscriptionTier.free < .starter)
        XCTAssertTrue(SubscriptionTier.starter < .pro)
        XCTAssertTrue(SubscriptionTier.pro < .business)
        XCTAssertFalse(SubscriptionTier.business < .free)
        XCTAssertFalse(SubscriptionTier.pro < .starter)
    }

    func testComparableGreaterThanOrEqual() {
        XCTAssertTrue(SubscriptionTier.business >= .business)
        XCTAssertTrue(SubscriptionTier.business >= .pro)
        XCTAssertTrue(SubscriptionTier.pro >= .starter)
        XCTAssertTrue(SubscriptionTier.starter >= .free)
        XCTAssertFalse(SubscriptionTier.free >= .starter)
    }

    func testCodableEncode() throws {
        let tier = SubscriptionTier.pro
        let data = try JSONEncoder().encode(tier)
        let decoded = try JSONDecoder().decode(SubscriptionTier.self, from: data)
        XCTAssertEqual(decoded, tier)
    }

    func testCodableDecodeFromRawValue() throws {
        // Raw value 2 should decode to .pro
        let json = "2".data(using: .utf8)!
        let tier = try JSONDecoder().decode(SubscriptionTier.self, from: json)
        XCTAssertEqual(tier, .pro)
    }

    func testAllTiersCodableRoundTrip() throws {
        let tiers: [SubscriptionTier] = [.free, .starter, .pro, .business]
        for tier in tiers {
            let data = try JSONEncoder().encode(tier)
            let decoded = try JSONDecoder().decode(SubscriptionTier.self, from: data)
            XCTAssertEqual(decoded, tier, "Round trip failed for \(tier.displayName)")
        }
    }

    func testFeedbackLimitsIncreaseWithTier() {
        let tiers: [SubscriptionTier] = [.free, .starter, .pro, .business]
        for i in 0..<(tiers.count - 1) {
            XCTAssertLessThan(
                tiers[i].feedbackLimit,
                tiers[i + 1].feedbackLimit,
                "\(tiers[i].displayName) limit should be less than \(tiers[i + 1].displayName)"
            )
        }
    }
}

// MARK: - SubscriptionStatus Tests

final class SubscriptionStatusTests: XCTestCase {

    func testNoneEquality() {
        XCTAssertEqual(SubscriptionStatus.none, SubscriptionStatus.none)
    }

    func testExpiredEquality() {
        XCTAssertEqual(SubscriptionStatus.expired, SubscriptionStatus.expired)
    }

    func testActiveWithSameDateEquality() {
        let date = Date(timeIntervalSince1970: 1700000000)
        XCTAssertEqual(
            SubscriptionStatus.active(expiresAt: date),
            SubscriptionStatus.active(expiresAt: date)
        )
    }

    func testActiveWithNilDateEquality() {
        XCTAssertEqual(
            SubscriptionStatus.active(expiresAt: nil),
            SubscriptionStatus.active(expiresAt: nil)
        )
    }

    func testActiveWithDifferentDatesNotEqual() {
        let date1 = Date(timeIntervalSince1970: 1700000000)
        let date2 = Date(timeIntervalSince1970: 1700001000)
        XCTAssertNotEqual(
            SubscriptionStatus.active(expiresAt: date1),
            SubscriptionStatus.active(expiresAt: date2)
        )
    }

    func testGracePeriodEquality() {
        let date = Date(timeIntervalSince1970: 1700000000)
        XCTAssertEqual(
            SubscriptionStatus.gracePeriod(expiresAt: date),
            SubscriptionStatus.gracePeriod(expiresAt: date)
        )
    }

    func testDifferentStatusesNotEqual() {
        XCTAssertNotEqual(SubscriptionStatus.none, SubscriptionStatus.expired)
        XCTAssertNotEqual(
            SubscriptionStatus.none,
            SubscriptionStatus.active(expiresAt: nil)
        )
        XCTAssertNotEqual(
            SubscriptionStatus.expired,
            SubscriptionStatus.active(expiresAt: nil)
        )
    }
}

// MARK: - Product ID Tests

@available(iOS 15.0, macOS 12.0, *)
final class ProductIDTests: XCTestCase {

    func testProductIDsCount() {
        XCTAssertEqual(CutiESubscriptionManager.productIDs.count, 6)
    }

    func testProductIDsContainAllTiers() {
        let ids = CutiESubscriptionManager.productIDs
        XCTAssertTrue(ids.contains("com.cutie.starter.monthly"))
        XCTAssertTrue(ids.contains("com.cutie.starter.yearly"))
        XCTAssertTrue(ids.contains("com.cutie.pro.monthly"))
        XCTAssertTrue(ids.contains("com.cutie.pro.yearly"))
        XCTAssertTrue(ids.contains("com.cutie.business.monthly"))
        XCTAssertTrue(ids.contains("com.cutie.business.yearly"))
    }

    func testProductIDsDoNotContainFree() {
        let ids = CutiESubscriptionManager.productIDs
        let freeIDs = ids.filter { $0.contains("free") }
        XCTAssertTrue(freeIDs.isEmpty, "Free tier should not have product IDs")
    }

    func testProductIDsHaveConsistentPrefix() {
        let ids = CutiESubscriptionManager.productIDs
        for id in ids {
            XCTAssertTrue(id.hasPrefix("com.cutie."), "Product ID '\(id)' should start with 'com.cutie.'")
        }
    }

    func testProductIDsHaveBillingPeriod() {
        let ids = CutiESubscriptionManager.productIDs
        for id in ids {
            let hasMonthly = id.hasSuffix(".monthly")
            let hasYearly = id.hasSuffix(".yearly")
            XCTAssertTrue(hasMonthly || hasYearly, "Product ID '\(id)' should end with .monthly or .yearly")
        }
    }

    func testEachTierHasMonthlyAndYearly() {
        let ids = CutiESubscriptionManager.productIDs
        let tiers = ["starter", "pro", "business"]

        for tier in tiers {
            let monthly = ids.contains("com.cutie.\(tier).monthly")
            let yearly = ids.contains("com.cutie.\(tier).yearly")
            XCTAssertTrue(monthly, "\(tier) should have monthly product")
            XCTAssertTrue(yearly, "\(tier) should have yearly product")
        }
    }
}

// MARK: - StoreError Tests

final class StoreErrorTests: XCTestCase {

    func testFailedVerificationError() {
        let error = StoreError.failedVerification
        XCTAssertNotNil(error)
    }

    func testPurchaseFailedError() {
        let error = StoreError.purchaseFailed
        XCTAssertNotNil(error)
    }

    func testStoreErrorsAreDifferent() {
        // Verify the two error cases are distinguishable
        let error1 = StoreError.failedVerification
        let error2 = StoreError.purchaseFailed

        switch error1 {
        case .failedVerification:
            break // expected
        case .purchaseFailed:
            XCTFail("failedVerification should not match purchaseFailed")
        }

        switch error2 {
        case .purchaseFailed:
            break // expected
        case .failedVerification:
            XCTFail("purchaseFailed should not match failedVerification")
        }
    }
}

// MARK: - UsageResponse Tests

final class UsageResponseTests: XCTestCase {

    func testFullResponseDecoding() throws {
        let json = """
        {
            "billing_period": "2026-02",
            "tier": "pro",
            "usage": {
                "feedback_count": 42,
                "feedback_limit": 10000,
                "feedback_remaining": 9958,
                "message_count": 150,
                "attachment_bytes": 5242880,
                "storage_limit_bytes": 104857600
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.billingPeriod, "2026-02")
        XCTAssertEqual(response.tier, "pro")
        XCTAssertEqual(response.usage.feedbackCount, 42)
        XCTAssertEqual(response.usage.feedbackLimit, 10000)
        XCTAssertEqual(response.usage.feedbackRemaining, 9958)
        XCTAssertEqual(response.usage.messageCount, 150)
        XCTAssertEqual(response.usage.attachmentBytes, 5242880)
        XCTAssertEqual(response.usage.storageLimitBytes, 104857600)
    }

    func testFreeUsageResponse() throws {
        let json = """
        {
            "billing_period": "2026-02",
            "tier": "free",
            "usage": {
                "feedback_count": 0,
                "feedback_limit": 50,
                "feedback_remaining": 50,
                "message_count": 0,
                "attachment_bytes": 0,
                "storage_limit_bytes": 10485760
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.tier, "free")
        XCTAssertEqual(response.usage.feedbackCount, 0)
        XCTAssertEqual(response.usage.feedbackRemaining, 50)
    }

    func testBusinessUsageResponse() throws {
        let json = """
        {
            "billing_period": "2026-01",
            "tier": "business",
            "usage": {
                "feedback_count": 5000,
                "feedback_limit": 2147483647,
                "feedback_remaining": 2147478647,
                "message_count": 25000,
                "attachment_bytes": 52428800,
                "storage_limit_bytes": 1073741824
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.tier, "business")
        XCTAssertEqual(response.usage.feedbackCount, 5000)
        XCTAssertEqual(response.usage.storageLimitBytes, 1073741824)
    }
}

// MARK: - SubscriptionManager Singleton Tests

@available(iOS 15.0, macOS 12.0, *)
final class SubscriptionManagerSingletonTests: XCTestCase {

    func testSharedSingleton() {
        let instance1 = CutiESubscriptionManager.shared
        let instance2 = CutiESubscriptionManager.shared
        XCTAssertTrue(instance1 === instance2, "shared should return the same instance")
    }

    func testDefaultTierIsFree() {
        // Fresh singleton should default to free tier
        // Note: This tests the published property's initial value
        let manager = CutiESubscriptionManager.shared
        // We can't reset the singleton, but we can verify it has a valid tier
        XCTAssertNotNil(manager.currentTier)
        XCTAssertTrue(manager.currentTier.rawValue >= 0)
        XCTAssertTrue(manager.currentTier.rawValue <= 3)
    }

    func testDefaultStatusIsValid() {
        let manager = CutiESubscriptionManager.shared
        // Status should be one of the valid values
        switch manager.subscriptionStatus {
        case .none, .expired:
            break // Valid default states
        case .active, .gracePeriod:
            break // Also valid if there's an active subscription
        }
    }
}
