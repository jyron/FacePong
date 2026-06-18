// Store.swift — StoreKit 2 in-app purchases: per-rival unlocks, an all-access
// bundle (which also grants unlimited hearts), and a consumable heart refill.
//
// Entitlement source of truth = Transaction.currentEntitlements (signed, offline-
// cached, no backend). We also listen to Transaction.updates for Ask-to-Buy /
// Family Sharing / refunds, verify every transaction, and expose Restore
// (AppStore.sync) — all required to pass App Review for non-consumables.
//
// DEBUG note: when StoreKit products fail to load (e.g. running in the Simulator
// via `simctl` with no .storekit config attached to the launch), the store drops
// into a local "demo" mode so the paywall UX is fully testable — prices come from
// a fallback table and a "purchase" grants the entitlement locally. The real
// StoreKit path is unchanged for Xcode-run / TestFlight / production.
import StoreKit
import Combine
import PostHog

@MainActor
final class Store: ObservableObject {
    static let allAccessID = "com.facepong.unlock.all"
    static let heartsRefillID = "com.facepong.hearts.refill5"

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var unlockedIDs: Set<String> = []   // owned non-consumables
    @Published private(set) var loaded = false
    @Published var purchasing: String? = nil                    // product id mid-purchase

    /// GameModel wires these so a purchase updates the rest of the app.
    var onHeartsRefill: (() -> Void)?
    var onEntitlementsChanged: (() -> Void)?

    private var updatesTask: Task<Void, Never>?

    static let fallbackPrices: [String: String] = [
        "com.facepong.unlock.interesting": "$1.99",
        "com.facepong.unlock.wrestler": "$1.99",
        "com.facepong.unlock.champ": "$1.99",
        "com.facepong.unlock.dictator": "$2.99",
        "com.facepong.unlock.president": "$2.99",
        "com.facepong.unlock.chairman": "$2.99",
        allAccessID: "$9.99",
        heartsRefillID: "$0.99",
    ]

    var allProductIDs: [String] {
        Rival.roster.filter { $0.premium }.map(\.unlockProductID) + [Store.allAccessID, Store.heartsRefillID]
    }

    var hasAllAccess: Bool { unlockedIDs.contains(Store.allAccessID) }

    func isUnlocked(_ rival: Rival) -> Bool {
        !rival.premium || hasAllAccess || unlockedIDs.contains(rival.unlockProductID)
    }

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates { await self?.handle(update) }
        }
        Task { await load(); await refreshEntitlements() }
    }
    deinit { updatesTask?.cancel() }

    // MARK: loading

    func load() async {
        do {
            let prods = try await Product.products(for: allProductIDs)
            var map: [String: Product] = [:]
            for p in prods { map[p.id] = p }
            products = map
        } catch { products = [:] }
        loaded = true
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.revocationDate == nil { owned.insert(t.productID) }
        }
        #if DEBUG
        owned.formUnion(Set(UserDefaults.standard.stringArray(forKey: "fp.debugUnlocked") ?? []))
        #endif
        unlockedIDs = owned
        onEntitlementsChanged?()
    }

    func displayPrice(_ id: String) -> String {
        products[id]?.displayPrice ?? Store.fallbackPrices[id] ?? "$0.99"
    }

    // MARK: purchase / restore

    /// Returns true if the purchase succeeded and the entitlement/heart was granted.
    func buy(_ id: String) async -> Bool {
        purchasing = id
        defer { purchasing = nil }

        guard let product = products[id] else {
            #if DEBUG
            return demoGrant(id)   // Simulator-without-config fallback
            #else
            return false
            #endif
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let t) = verification else { return false }
                await apply(t)
                await t.finish()
                PostHogSDK.shared.capture("purchase_completed", properties: ["product_id": id])
                return true
            case .pending, .userCancelled:
                PostHogSDK.shared.capture("purchase_failed", properties: [
                    "product_id": id,
                    "reason": "cancelled",
                ])
                return false
            @unknown default: return false
            }
        } catch {
            PostHogSDK.shared.capture("purchase_failed", properties: [
                "product_id": id,
                "reason": "error",
            ])
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else { return }
        await apply(t)
        await t.finish()
    }

    private func apply(_ t: Transaction) async {
        if t.productID == Store.heartsRefillID {
            if t.revocationDate == nil { onHeartsRefill?() }   // a refunded refill is a no-op, not a re-grant
        } else if t.revocationDate == nil {
            unlockedIDs.insert(t.productID)
            onEntitlementsChanged?()
        } else {
            unlockedIDs.remove(t.productID)
            onEntitlementsChanged?()
        }
    }

    #if DEBUG
    private func demoGrant(_ id: String) -> Bool {
        if id == Store.heartsRefillID { onHeartsRefill?(); return true }
        var set = Set(UserDefaults.standard.stringArray(forKey: "fp.debugUnlocked") ?? [])
        set.insert(id)
        UserDefaults.standard.set(Array(set), forKey: "fp.debugUnlocked")
        unlockedIDs.insert(id)
        onEntitlementsChanged?()
        return true
    }
    static func debugResetUnlocks() { UserDefaults.standard.removeObject(forKey: "fp.debugUnlocked") }
    #endif
}
