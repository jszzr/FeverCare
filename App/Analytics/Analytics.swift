import Foundation
import os

/// 匿名使用统计,用于留存分析。合规红线的延伸,三条硬约束:
/// 1. 绝不发送任何健康数据:没有体温值、没有药名、没有孩子信息、没有自由文本;
///    事件参数只允许预定义的枚举值与非敏感维度(App 版本、安装后天数)。
/// 2. 用户标识是本机随机生成的匿名 ID,与 Apple 账号、设备标识均无关联。
/// 3. 用户可在「设置 → 隐私」随时关闭(analyticsEnabled)。
enum AnalyticsEvent: String {
    case appOpened = "app_opened"
    case episodeStarted = "episode_started"
    case eventRecorded = "event_recorded"
    case reportExported = "report_exported"
    case paywallShown = "paywall_shown"
    case purchaseCompleted = "purchase_completed"
    case purchaseRestored = "purchase_restored"
}

@MainActor
final class Analytics {
    static let shared = Analytics()

    /// TelemetryDeck 的 App ID。留空 = 不发起任何网络请求,事件只写本地调试日志。
    /// 注册 telemetrydeck.com 后把 ID 填在这里即可开始收数。
    private static let telemetryAppID = ""
    private static let endpoint = URL(string: "https://nom.telemetrydeck.com/v2/")!

    /// 让设置页与实际网络行为保持一致：未配置 App ID 时不提供一个无效开关。
    static var isConfigured: Bool { !telemetryAppID.isEmpty }

    static let enabledKey = "analyticsEnabled"
    private static let anonymousIDKey = "analyticsAnonymousID"

    private let logger = Logger(subsystem: "com.zhirui.shaotuitui", category: "Analytics")

    private init() {}

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// 本机随机匿名 ID,首次使用时生成
    private var anonymousID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: Self.anonymousIDKey) { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: Self.anonymousIDKey)
        return fresh
    }

    /// 留存分析的核心维度:安装后第几天(0 = 安装当天)
    private var daysSinceInstall: Int {
        let first = UserDefaults.standard.object(forKey: PurchaseManager.firstLaunchKey) as? Date ?? Date()
        return max(0, Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 0)
    }

    func track(_ event: AnalyticsEvent, _ extra: [String: String] = [:]) {
        var payload = extra
        payload["appVersion"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        payload["daysSinceInstall"] = String(daysSinceInstall)
        logger.debug("track \(event.rawValue) \(payload)")

        guard isEnabled, !Self.telemetryAppID.isEmpty else { return }

        let signal: [String: Any] = [
            "appID": Self.telemetryAppID,
            "clientUser": anonymousID,
            "signalType": event.rawValue,
            "payload": payload,
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: [signal]) else { return }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        Task.detached(priority: .utility) {
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
