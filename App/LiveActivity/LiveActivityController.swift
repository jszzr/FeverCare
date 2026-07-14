import Foundation
import ActivityKit
import os

/// 管理锁屏/灵动岛的 Live Activity。
/// 约定:任何事件增删改、病程开始/结束之后,调用 `sync(episode:)`。
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private let logger = Logger(subsystem: "com.zhirui.fevercare", category: "LiveActivity")

    private init() {}

    static let enabledKey = "liveActivityEnabled"

    private var userEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// 让 Live Activity 与当前活跃病程保持一致:
    /// - 病程为 nil / 已结束 / 用户关闭了开关 → 结束所有 activity
    /// - 有活跃病程 → 不存在则创建,存在则更新
    func sync(episode: Episode?) {
        Task { await self.syncAsync(episode: episode) }
    }

    private func syncAsync(episode: Episode?) async {
        guard let episode, episode.isActive, userEnabled else {
            await endAll()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities disabled by system settings")
            return
        }

        let state = contentState(for: episode)
        let content = ActivityContent(state: state, staleDate: nil)

        if let activity = Activity<FeverActivityAttributes>.activities.first {
            await activity.update(content)
            return
        }

        let attributes = FeverActivityAttributes(
            childName: episode.child?.name ?? "宝宝",
            episodeStartedAt: episode.startedAt
        )
        do {
            _ = try Activity.request(attributes: attributes, content: content)
        } catch {
            logger.error("Failed to start live activity: \(error.localizedDescription)")
        }
    }

    func endAll() async {
        for activity in Activity<FeverActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
    }

    private func contentState(for episode: Episode) -> FeverActivityAttributes.ContentState {
        let latestTemp = episode.latestTemperatureEvent
        let lastMed = episode.lastMedicationEvent
        return FeverActivityAttributes.ContentState(
            latestTempC: latestTemp?.temperatureC,
            latestTempAt: latestTemp?.timestamp,
            lastMedName: lastMed?.medicationName,
            lastMedAt: lastMed?.timestamp,
            eventCount: episode.events.count,
            tempUnitRaw: UserDefaults.standard.string(forKey: "tempUnit") ?? TempUnit.celsius.rawValue
        )
    }
}
