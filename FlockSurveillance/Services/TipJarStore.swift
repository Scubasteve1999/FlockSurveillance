import Foundation
import StoreKit

enum TipProductID: String, CaseIterable, Identifiable {
    case small = "com.flocksurveillance.app.tip.small"
    case medium = "com.flocksurveillance.app.tip.medium"
    case large = "com.flocksurveillance.app.tip.large"

    var id: String { rawValue }

    var fallbackName: String {
        switch self {
        case .small: return "Small tip"
        case .medium: return "Medium tip"
        case .large: return "Large tip"
        }
    }
}

enum TipJarCopy {
    static let eyebrow = "SUPPORT"
    static let body = "The app stays free. A tip is optional and unlocks nothing."
    static let thankYou = "Thank you — that keeps the map independent."
    static let unavailable = "Tips aren’t available on this build yet."
    static let purchaseFailed = "Couldn’t complete the tip. Try again."
    static let working = "Working…"

    static var userFacingStrings: [String] {
        [eyebrow, body, thankYou, unavailable, purchaseFailed, working]
    }
}

enum TipJarPhase: Equatable {
    case idle
    case loading
    case purchasing
    case thankYou
    case unavailable
    case failed(String)
}

@MainActor
@Observable
final class TipJarStore {
    static let tipCountKey = "tips.count"

    var products: [Product] = []
    var phase: TipJarPhase = .idle

    var tipCount: Int {
        UserDefaults.standard.integer(forKey: Self.tipCountKey)
    }

    private var handledTransactionIDs: Set<UInt64> = []
    private var updatesTask: Task<Void, Never>?

    func load() async {
        startListeningIfNeeded()
        guard phase != .purchasing else { return }
        phase = .loading
        do {
            let ids = Set(TipProductID.allCases.map(\.rawValue))
            let loaded = try await Product.products(for: ids)
            products = TipProductID.allCases.compactMap { id in
                loaded.first(where: { $0.id == id.rawValue })
            }
            phase = products.isEmpty ? .unavailable : .idle
        } catch {
            products = []
            phase = .unavailable
        }
    }

    func purchase(_ product: Product) async {
        phase = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await record(transaction)
            case .userCancelled, .pending:
                phase = .idle
            @unknown default:
                phase = .idle
            }
        } catch {
            phase = .failed(TipJarCopy.purchaseFailed)
        }
    }

    func displayName(for product: Product) -> String {
        if let known = TipProductID(rawValue: product.id) {
            return known.fallbackName
        }
        return product.displayName
    }

    private func startListeningIfNeeded() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.record(transaction)
                } catch {
                    continue
                }
            }
        }
    }

    private func record(_ transaction: Transaction) async {
        await transaction.finish()
        guard TipProductID(rawValue: transaction.productID) != nil else { return }
        guard handledTransactionIDs.insert(transaction.id).inserted else { return }
        let next = tipCount + 1
        UserDefaults.standard.set(next, forKey: Self.tipCountKey)
        phase = .thankYou
        Task {
            try? await Task.sleep(for: .seconds(4))
            if phase == .thankYou {
                phase = .idle
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
