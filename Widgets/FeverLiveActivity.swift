import SwiftUI
import WidgetKit
import ActivityKit

// ⚠️ 本 target 不能访问 App/ 下的类型(Temp/Brand/Fmt 均不可用),
// 需要的小工具函数在本文件内自带(分级色逻辑复制自 Theme.swift 的 Temp.color)。

// MARK: - 本地小工具(仅本 Widget target 使用)

/// 体温分级展示色(仅作视觉参考,不构成判断建议)。逻辑与主 App Theme.swift 中 Temp.color 保持一致。
private func feverTempColor(for celsius: Double) -> Color {
    switch celsius {
    case ..<37.3: return .green
    case 37.3..<38.0: return .yellow
    case 38.0..<39.0: return .orange
    default: return .red
    }
}

/// 按用户单位偏好显示的体温数值串(不带单位),如 "38.5" / "101.3";无记录时为 "--"
private func feverTempNumber(_ celsius: Double?, unitRaw: String) -> String {
    guard let celsius else { return "--" }
    let value = unitRaw == "fahrenheit" ? celsius * 9 / 5 + 32 : celsius
    return String(format: "%.1f", value)
}

/// 单位符号,与主 App Theme.swift 的 Temp.unitSymbol 一致
private func feverUnitSymbol(_ unitRaw: String) -> String {
    unitRaw == "fahrenheit" ? "℉" : "℃"
}

/// 体温对应的展示色;无记录时用灰色
private func feverTempColor(forOptional celsius: Double?) -> Color {
    guard let celsius else { return .gray }
    return feverTempColor(for: celsius)
}

// MARK: - Live Activity

struct FeverLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeverActivityAttributes.self) { context in
            // 锁屏 / 横幅视图
            FeverLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.childName)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 3) {
                            Text("已发烧")
                            Text(timerInterval: context.attributes.episodeStartedAt...Date.distantFuture, countsDown: false)
                                .monospacedDigit()
                                .frame(maxWidth: 60, alignment: .leading)
                                .minimumScaleFactor(0.7)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(feverTempNumber(context.state.latestTempC, unitRaw: context.state.tempUnitRaw))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(feverTempColor(forOptional: context.state.latestTempC))
                        if context.state.latestTempC != nil {
                            Text(feverUnitSymbol(context.state.tempUnitRaw))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 4) {
                        Image(systemName: "pills.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        if let medName = context.state.lastMedName, let medAt = context.state.lastMedAt {
                            Text("上次用药〔\(medName)〕已过")
                                .lineLimit(1)
                            Text(timerInterval: medAt...Date.distantFuture, countsDown: false)
                                .monospacedDigit()
                                .frame(maxWidth: 60, alignment: .leading)
                                .minimumScaleFactor(0.7)
                        } else {
                            Text("尚未用药")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "thermometer.variable")
                    .foregroundStyle(feverTempColor(forOptional: context.state.latestTempC))
            } compactTrailing: {
                Text(feverTempNumber(context.state.latestTempC, unitRaw: context.state.tempUnitRaw) + "°")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(feverTempColor(forOptional: context.state.latestTempC))
            } minimal: {
                Text(feverTempNumber(context.state.latestTempC, unitRaw: context.state.tempUnitRaw) + "°")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(feverTempColor(forOptional: context.state.latestTempC))
            }
        }
    }
}

// MARK: - 锁屏视图

struct FeverLockScreenView: View {
    let context: ActivityViewContext<FeverActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                // 左侧:孩子名 + "已发烧"计时
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.childName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 3) {
                        Text("已发烧")
                        Text(timerInterval: context.attributes.episodeStartedAt...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                            .frame(maxWidth: 64, alignment: .leading)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                }

                Spacer(minLength: 8)

                // 中间/右侧:最新体温大字(按分级着色,无记录显示 "--")
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(feverTempNumber(context.state.latestTempC, unitRaw: context.state.tempUnitRaw))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(feverTempColor(forOptional: context.state.latestTempC))
                    if context.state.latestTempC != nil {
                        Text(feverUnitSymbol(context.state.tempUnitRaw))
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            // 下行:上次用药事实陈述(仅记录事实,不作任何建议)
            HStack(spacing: 4) {
                Image(systemName: "pills.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                if let medName = context.state.lastMedName, let medAt = context.state.lastMedAt {
                    Text("上次用药〔\(medName)〕已过")
                        .lineLimit(1)
                    Text(timerInterval: medAt...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .frame(maxWidth: 64, alignment: .leading)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("尚未用药")
                }
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
    }
}
