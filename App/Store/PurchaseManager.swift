import Foundation
import StoreKit
import os

/// 一次性买断的内购管理(StoreKit 2)。
/// 商业模型:免费下载 → 前 `trialDays` 天完整功能试用 → 之后新增记录需买断解锁。
/// 原则:已有数据永远可以查看、编辑、导出——绝不拿用户的健康记录当人质。
@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    nonisolated static let productID = "com.zhirui.shaotuitui.lifetime"
    nonisolated static let trialDays = 7
    nonisolated static let firstLaunchKey = "firstLaunchAt"

    @Published private(set) var isPurchased = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    @Published var lastError: String?

    private let logger = Logger(subsystem: "com.zhirui.shaotuitui", category: "Purchase")
    private var updatesTask: Task<Void, Never>?

    private init() {
        let defaults = UserDefaults.standard
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ResetTrial") {
            defaults.removeObject(forKey: Self.firstLaunchKey)
        }
        if args.contains("-TrialExpired") {
            defaults.set(Date().addingTimeInterval(-86400 * 30), forKey: Self.firstLaunchKey)
        }
        #endif
        if defaults.object(forKey: Self.firstLaunchKey) == nil {
            defaults.set(Date(), forKey: Self.firstLaunchKey)
        }
        updatesTask = Task { await listenForTransactions() }
        Task { await refresh() }
    }

    // MARK: 试用期

    var firstLaunchAt: Date {
        UserDefaults.standard.object(forKey: Self.firstLaunchKey) as? Date ?? Date()
    }

    var trialEndsAt: Date {
        Calendar.current.date(byAdding: .day, value: Self.trialDays, to: firstLaunchAt) ?? firstLaunchAt
    }

    var isInTrial: Bool { Date() < trialEndsAt }

    /// 试用剩余天数(向上取整:最后一天显示 1)
    var trialDaysRemaining: Int {
        let seconds = trialEndsAt.timeIntervalSinceNow
        guard seconds > 0 else { return 0 }
        return max(1, Int(ceil(seconds / 86400)))
    }

    /// 是否可以新增记录:已买断,或仍在试用期
    var hasFullAccess: Bool { isPurchased || isInTrial }

    // MARK: 商品与购买

    func refresh(showProductError: Bool = false) async {
        var ownsProduct = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                ownsProduct = true
            }
        }
        isPurchased = ownsProduct
        await loadProduct(showError: showProductError)
    }

    /// StoreKit 在购买账户尚未认证、网络切换或沙盒暂时不可用时，可能返回空数组而不抛错。
    /// 因此这里显式维护加载状态并做短重试，避免 UI 永久停在“价格加载中”。
    func loadProduct(showError: Bool = true) async {
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }

        var lastLoadError: Error?
        for attempt in 0..<3 {
            if Task.isCancelled { return }
            do {
                if let loadedProduct = try await Product.products(for: [Self.productID]).first {
                    product = loadedProduct
                    return
                }
                logger.error("StoreKit returned no product for \(Self.productID, privacy: .public)")
            } catch {
                lastLoadError = error
                logger.error("Failed to load product: \(error.localizedDescription, privacy: .public)")
            }

            if attempt < 2 {
                try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_000_000_000)
            }
        }

        product = nil
        guard showError else { return }
        if let lastLoadError {
            logger.error("Product loading exhausted retries: \(lastLoadError.localizedDescription, privacy: .public)")
        }
        lastError = "暂时无法从 App Store 获取价格。请检查网络和“媒体与购买项目”的登录状态后重试。"
    }

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    isPurchased = true
                    await transaction.finish()
                    Analytics.shared.track(.purchaseCompleted)
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            lastError = "购买未完成,请稍后再试。"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            lastError = "无法连接 App Store 恢复购买，请检查账号登录和网络后重试。"
            return
        }
        await refresh()
        if isPurchased {
            Analytics.shared.track(.purchaseRestored)
        } else {
            lastError = "没有找到可恢复的购买记录。"
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.productID {
                    isPurchased = transaction.revocationDate == nil
                }
                await transaction.finish()
            }
        }
    }
}
