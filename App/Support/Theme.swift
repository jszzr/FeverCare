import SwiftUI

// MARK: - 温度单位

enum TempUnit: String, CaseIterable {
    case celsius
    case fahrenheit

    var label: String {
        switch self {
        case .celsius: return "摄氏 ℃"
        case .fahrenheit: return "华氏 ℉"
        }
    }
}

enum Temp {
    /// 摄氏 → 当前单位的显示字符串,如 "38.5℃" / "101.3℉"
    static func display(_ celsius: Double, unit: TempUnit) -> String {
        switch unit {
        case .celsius:
            return String(format: "%.1f℃", celsius)
        case .fahrenheit:
            return String(format: "%.1f℉", celsius * 9 / 5 + 32)
        }
    }

    /// 不带单位符号的数值串,用于大字号展示
    static func number(_ celsius: Double, unit: TempUnit) -> String {
        switch unit {
        case .celsius:
            return String(format: "%.1f", celsius)
        case .fahrenheit:
            return String(format: "%.1f", celsius * 9 / 5 + 32)
        }
    }

    static func unitSymbol(_ unit: TempUnit) -> String {
        unit == .celsius ? "℃" : "℉"
    }

    /// 常用医学分级的展示色(仅作视觉参考,不构成判断建议)
    static func color(for celsius: Double) -> Color {
        switch celsius {
        case ..<37.3: return .green
        case 37.3..<38.0: return .yellow
        case 38.0..<39.0: return .orange
        default: return .red
        }
    }

    static func levelLabel(for celsius: Double) -> String {
        switch celsius {
        case ..<37.3: return "正常范围"
        case 37.3..<38.0: return "低热"
        case 38.0..<39.0: return "中度发热"
        default: return "高热"
        }
    }
}

// MARK: - 品牌与样式

enum Brand {
    static let accent = Color(red: 0.96, green: 0.42, blue: 0.35)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let pageBackground = Color(.systemGroupedBackground)
}

/// 深夜场景的大按钮:目标是"迷糊状态下闭着眼也能按到"
struct BigActionButtonStyle: ButtonStyle {
    var tint: Color = Brand.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(tint.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 通用格式化

enum Fmt {
    static let timeHM: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let monthDayTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    /// "3小时12分" 这样的已过时长
    static func hoursMinutes(since date: Date, to now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "刚刚" }
        if minutes < 60 { return "\(minutes)分钟" }
        return "\(minutes / 60)小时\(minutes % 60)分"
    }
}
