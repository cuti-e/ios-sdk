import Foundation
import StoreKit

/// Manages in-app subscription purchases and status using StoreKit 2.
///
/// `CutiESubscriptionManager` provides a complete subscription management solution
/// including product loading, purchase handling, receipt validation, and status tracking.
/// It automatically syncs subscription state with your Cuti-E backend.
///
/// ## Overview
///
/// The subscription manager is an `ObservableObject` that publishes subscription state
/// changes, making it easy to integrate with SwiftUI views.
///
/// ## Usage
///
/// Access the manager through the main SDK instance:
///
/// ```swift
/// let subscriptionManager = CutiE.shared.subscriptionManager
///
/// // Check current tier
/// switch subscriptionManager.currentTier {
/// case .free:
///     showUpgradePrompt()
/// case .starter, .pro, .business:
///     enablePremiumFeatures()
/// }
/// ```
///
/// ### Displaying Available Plans
///
/// ```swift
/// struct SubscriptionView: View {
///     @ObservedObject var manager = CutiE.shared.subscriptionManager
///
///     var body: some View {
///         List(manager.products, id: \.id) { product in
///             Button(product.displayName) {
///                 Task {
///                     await manager.purchase(product)
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Subscription State
///
/// - ``currentTier``
/// - ``subscriptionStatus``
/// - ``SubscriptionTier``
/// - ``SubscriptionStatus``
///
/// ### Products
///
/// - ``products``
/// - ``isLoading``
/// - ``loadProducts()``
///
/// ### Purchasing
///
/// - ``purchase(_:)``
/// - ``restorePurchases()``
@available(iOS 15.0, macOS 12.0, *)
public class CutiESubscriptionManager: ObservableObject {

    /// The shared singleton instance.
    ///
    /// Access through `CutiE.shared.subscriptionManager` for proper SDK integration.
    public static let shared = CutiESubscriptionManager()

    /// The user's current subscription tier.
    ///
    /// This property reflects the highest active subscription tier. It updates
    /// automatically when subscriptions are purchased, renewed, or expire.
    ///
    /// ```swift
    /// if CutiE.shared.subscriptionManager.currentTier >= .pro {
    ///     // Enable Pro features
    /// }
    /// ```
    @Published public private(set) var currentTier: SubscriptionTier = .free

    /// The current subscription status.
    ///
    /// Indicates whether the user has an active subscription and when it expires.
    ///
    /// ```swift
    /// switch subscriptionManager.subscriptionStatus {
    /// case .active(let expiresAt):
    ///     if let date = expiresAt {
    ///         print("Subscription expires: \(date)")
    ///     }
    /// case .expired:
    ///     showRenewalPrompt()
    /// case .none:
    ///     showSubscriptionOptions()
    /// case .gracePeriod(let expiresAt):
    ///     showGracePeriodWarning(until: expiresAt)
    /// }
    /// ```
    @Published public private(set) var subscriptionStatus: SubscriptionStatus = .none

    /// Available subscription products from the App Store.
    ///
    /// This array is populated after calling ``loadProducts()``. Products are
    /// sorted by tier (Starter, Pro, Business) and billing period (monthly first).
    @Published public private(set) var products: [Product] = []

    /// Indicates whether products are currently being loaded.
    ///
    /// Use this to show loading indicators in your UI:
    /// ```swift
    /// if manager.isLoading {
    ///     ProgressView()
    /// } else {
    ///     ProductList(products: manager.products)
    /// }
    /// ```
    @Published public private(set) var isLoading = false

    /// Error message from the last failed operation, if any.
    ///
    /// Check this after purchase or restore operations to display error feedback.
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

    /// Loads available subscription products from the App Store.
    ///
    /// Call this method to fetch the latest product information. Products are
    /// automatically sorted by tier and billing period.
    ///
    /// ```swift
    /// await CutiE.shared.subscriptionManager.loadProducts()
    ///
    /// for product in manager.products {
    ///     print("\(product.displayName): \(product.displayPrice)")
    /// }
    /// ```
    ///
    /// - Note: Products are loaded automatically when the manager initializes.
    ///   Call this method to refresh product data or retry after a failure.
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

    /// Initiates a purchase for the specified subscription product.
    ///
    /// This method handles the complete purchase flow including:
    /// - Presenting the App Store purchase UI
    /// - Verifying the transaction
    /// - Updating local subscription state
    /// - Syncing with your Cuti-E backend
    ///
    /// ```swift
    /// if let product = manager.products.first {
    ///     let success = await manager.purchase(product)
    ///     if success {
    ///         print("Purchase successful!")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter product: The `Product` to purchase from ``products``.
    ///
    /// - Returns: `true` if the purchase completed successfully, `false` if the user
    ///   cancelled, the transaction is pending, or an error occurred.
    ///
    /// - Note: Check ``errorMessage`` for details if the purchase fails.
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

    /// Restores previously purchased subscriptions.
    ///
    /// Call this method when users want to restore purchases, typically from a
    /// "Restore Purchases" button in your subscription UI. This syncs with the
    /// App Store to restore any active subscriptions.
    ///
    /// ```swift
    /// Button("Restore Purchases") {
    ///     Task {
    ///         await manager.restorePurchases()
    ///     }
    /// }
    /// ```
    ///
    /// - Note: Check ``errorMessage`` for details if the restore fails.
    @MainActor
    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Refreshes subscription status from the App Store.
    ///
    /// This method queries the App Store for current entitlements and updates
    /// ``currentTier`` and ``subscriptionStatus`` accordingly. It's called
    /// automatically after purchases and restores.
    ///
    /// ```swift
    /// // Manually refresh subscription status
    /// await manager.updateSubscriptionStatus()
    /// print("Current tier: \(manager.currentTier)")
    /// ```
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
            NSLog("[CutiE] Failed to sync subscription with backend: %@", error as NSError)
        }
    }
}

// MARK: - Supporting Types

/// Subscription tier levels for Cuti-E services.
///
/// Tiers are ordered by feature level, allowing comparison:
/// ```swift
/// if currentTier >= .pro {
///     enableAdvancedFeatures()
/// }
/// ```
public enum SubscriptionTier: Int, Comparable, Codable {
    /// Free tier with basic features.
    case free = 0
    /// Starter tier for small projects.
    case starter = 1
    /// Pro tier for growing teams.
    case pro = 2
    /// Business tier for enterprise needs.
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

/// Current status of the user's subscription.
public enum SubscriptionStatus: Equatable {
    /// No active subscription.
    case none
    /// Active subscription with optional expiration date.
    case active(expiresAt: Date?)
    /// Subscription has expired.
    case expired
    /// Subscription is in grace period (payment failed but access continues).
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
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Device-ID")

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
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Device-ID")

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
