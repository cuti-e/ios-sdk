import Foundation
import StoreKit

/// Manages subscription status and purchases using StoreKit 2
@available(iOS 15.0, macOS 12.0, *)
public class CutiESubscriptionManager: ObservableObject {

    /// Shared singleton instance
    public static let shared = CutiESubscriptionManager()

    /// Current subscription tier
    @Published public private(set) var currentTier: SubscriptionTier = .free

    /// Current subscription status
    @Published public private(set) var subscriptionStatus: SubscriptionStatus = .none

    /// Available products for purchase
    @Published public private(set) var products: [Product] = []

    /// Whether products are being loaded
    @Published public private(set) var isLoading = false

    /// Error message if any
    @Published public private(set) var errorMessage: String?

    /// Product IDs for subscriptions
    public static let productIDs: Set<String> = [
        "com.cutie.starter.monthly",
        "com.cutie.starter.yearly",
        "com.cutie.pro.monthly",
        "com.cutie.pro.yearly",
        "com.cutie.business.monthly",
        "com.cutie.business.yearly"
    ]

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public Methods

    /// Load available products from App Store
    @MainActor
    public func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { p1, p2 in
                // Sort by tier, then by monthly/yearly
                let tier1 = tierFromProductID(p1.id)
                let tier2 = tierFromProductID(p2.id)

                if tier1.rawValue != tier2.rawValue {
                    return tier1.rawValue < tier2.rawValue
                }

                return p1.id.contains("monthly")
            }
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Purchase a subscription product
    /// - Parameter product: The product to purchase
    /// - Returns: True if purchase was successful
    @MainActor
    public func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus()

                // Sync with backend
                await syncSubscriptionWithBackend(transaction: transaction)

                // Finish the transaction
                await transaction.finish()

                return true

            case .userCancelled:
                return false

            case .pending:
                // Transaction is pending (e.g., awaiting parental approval)
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    /// Restore purchases
    @MainActor
    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Update subscription status from App Store
    @MainActor
    public func updateSubscriptionStatus() async {
        var highestTier: SubscriptionTier = .free
        var activeSubscription: Transaction?

        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    let tier = tierFromProductID(transaction.productID)
                    if tier.rawValue > highestTier.rawValue {
                        highestTier = tier
                        activeSubscription = transaction
                    }
                }
            }
        }

        currentTier = highestTier

        if let subscription = activeSubscription {
            if let expirationDate = subscription.expirationDate {
                if expirationDate > Date() {
                    subscriptionStatus = .active(expiresAt: expirationDate)
                } else {
                    subscriptionStatus = .expired
                }
            } else {
                subscriptionStatus = .active(expiresAt: nil)
            }
        } else {
            subscriptionStatus = .none
        }
    }

    // MARK: - Private Methods

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    Task { @MainActor in
                        await self.updateSubscriptionStatus()
                    }

                    // Sync with backend
                    await self.syncSubscriptionWithBackend(transaction: transaction)

                    await transaction.finish()
                } catch {
                    // Handle verification error
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func tierFromProductID(_ productID: String) -> SubscriptionTier {
        if productID.contains("business") {
            return .business
        } else if productID.contains("pro") {
            return .pro
        } else if productID.contains("starter") {
            return .starter
        }
        return .free
    }

    private func syncSubscriptionWithBackend(transaction: Transaction) async {
        // Get the receipt data to verify with backend
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: appStoreReceiptURL) else {
            return
        }

        let receiptString = receiptData.base64EncodedString()

        // Call backend to verify receipt
        guard let client = CutiE.shared.apiClient else {
            return
        }

        do {
            try await client.verifyReceipt(
                platform: "ios",
                receiptData: receiptString,
                productId: transaction.productID
            )
        } catch {
            // Log error but don't fail - subscription still valid locally
            print("[CutiE] Failed to sync subscription with backend: \(error)")
        }
    }
}

// MARK: - Supporting Types

/// Subscription tiers
public enum SubscriptionTier: Int, Comparable, Codable {
    case free = 0
    case starter = 1
    case pro = 2
    case business = 3

    public static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .starter: return "Starter"
        case .pro: return "Pro"
        case .business: return "Business"
        }
    }

    public var feedbackLimit: Int {
        switch self {
        case .free: return 50
        case .starter: return 500
        case .pro: return 10_000
        case .business: return Int.max
        }
    }
}

/// Subscription status
public enum SubscriptionStatus: Equatable {
    case none
    case active(expiresAt: Date?)
    case expired
    case gracePeriod(expiresAt: Date)
}

/// Store errors
enum StoreError: Error {
    case failedVerification
    case purchaseFailed
}

// MARK: - API Client Extension

@available(iOS 15.0, macOS 12.0, *)
extension CutiEAPIClient {

    /// Verify App Store receipt with backend
    func verifyReceipt(platform: String, receiptData: String, productId: String) async throws {
        let endpoint = "\(configuration.apiURL)/v1/subscription/verify"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.appId, forHTTPHeaderField: "X-App-ID")
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Device-ID")
        if let apiKey = configuration.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        // Add device secret
        let secret = generateDeviceSecret()
        request.setValue(secret, forHTTPHeaderField: "X-Device-Secret")

        let body: [String: Any] = [
            "platform": platform,
            "receipt_data": receiptData,
            "product_id": productId
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CutiEError.networkError(NSError(domain: "CutiE", code: -1))
        }

        if httpResponse.statusCode >= 400 {
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw CutiEError.serverError(httpResponse.statusCode, errorData.error ?? "Unknown error")
            }
            throw CutiEError.serverError(httpResponse.statusCode, "Receipt verification failed")
        }
    }

    /// Get current usage from backend
    func getUsage() async throws -> UsageResponse {
        let endpoint = "\(configuration.apiURL)/v1/usage"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.setValue(configuration.appId, forHTTPHeaderField: "X-App-ID")
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Device-ID")
        if let apiKey = configuration.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        let secret = generateDeviceSecret()
        request.setValue(secret, forHTTPHeaderField: "X-Device-Secret")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CutiEError.networkError(NSError(domain: "CutiE", code: -1))
        }

        if httpResponse.statusCode >= 400 {
            throw CutiEError.serverError(httpResponse.statusCode, "Failed to get usage")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UsageResponse.self, from: data)
    }
}

// MARK: - Response Models

public struct UsageResponse: Codable {
    public let billingPeriod: String
    public let tier: String
    public let usage: Usage

    public struct Usage: Codable {
        public let feedbackCount: Int
        public let feedbackLimit: Int
        public let feedbackRemaining: Int
        public let messageCount: Int
        public let attachmentBytes: Int
        public let storageLimitBytes: Int
    }
}

private struct APIErrorResponse: Codable {
    let error: String?
}
