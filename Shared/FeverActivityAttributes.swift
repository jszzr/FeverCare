import Foundation
import ActivityKit

/// Live Activity 的数据契约,App 与 Widget 扩展共用。
struct FeverActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 最近一次体温(摄氏),nil 表示尚未记录
        var latestTempC: Double?
        var latestTempAt: Date?
        /// 最近一次用药
        var lastMedName: String?
        var lastMedAt: Date?
        /// 本次病程记录条数,用于展示
        var eventCount: Int
        /// 温度单位偏好(TempUnit.rawValue),App 在每次 sync 时写入当前设置
        var tempUnitRaw: String = "celsius"
    }

    /// 孩子名,病程开始时间——病程期间不变
    var childName: String
    var episodeStartedAt: Date
}
