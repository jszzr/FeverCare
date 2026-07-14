import SwiftUI
import SwiftData
import Charts

/// 体温曲线图:LineMark + PointMark(点按体温分级着色),
/// 用药事件以竖直 RuleMark + 顶部药丸标签标注。
/// compact 模式用于首页内嵌预览(高度约 140,隐藏轴标签细节)。
struct TemperatureChartView: View {
    let episode: Episode
    let compact: Bool

    @AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue
    private var unit: TempUnit { TempUnit(rawValue: tempUnitRaw) ?? .celsius }

    init(episode: Episode, compact: Bool = false) {
        self.episode = episode
        self.compact = compact
    }

    // MARK: - 绘图数据

    private struct TempPoint: Identifiable {
        let id: UUID
        let time: Date
        let celsius: Double
    }

    private struct MedPoint: Identifiable {
        let id: UUID
        let time: Date
        let name: String
    }

    private var tempPoints: [TempPoint] {
        episode.temperatureEvents.compactMap { event in
            guard let celsius = event.temperatureC else { return nil }
            return TempPoint(id: event.id, time: event.timestamp, celsius: celsius)
        }
    }

    private var medPoints: [MedPoint] {
        episode.medicationEvents.map { event in
            MedPoint(
                id: event.id,
                time: event.timestamp,
                name: (event.medicationName?.isEmpty == false) ? event.medicationName! : "用药"
            )
        }
    }

    private var chartHeight: CGFloat { compact ? 140 : 260 }

    // MARK: - 单位换算(内部一律摄氏,仅绘图/标注时换算)

    private func displayValue(_ celsius: Double) -> Double {
        unit == .celsius ? celsius : celsius * 9 / 5 + 32
    }

    /// clamp 到约 35–41℃ 后换算为当前单位的绘图值
    private func plotValue(forCelsius celsius: Double) -> Double {
        displayValue(min(max(celsius, 35.0), 41.0))
    }

    private var yDomain: ClosedRange<Double> {
        displayValue(34.8)...displayValue(41.2)
    }

    private var yGridValues: [Double] {
        stride(from: 35.0, through: 41.0, by: 1.0).map { displayValue($0) }
    }

    private func yGridLabel(for value: Double) -> String {
        String(format: unit == .celsius ? "%.0f" : "%.1f", value)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if tempPoints.isEmpty {
                placeholder
            } else if compact {
                chart
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(values: yGridValues) { _ in
                            AxisGridLine()
                        }
                    }
                    .frame(height: chartHeight)
            } else {
                chart
                    .chartYAxis {
                        AxisMarks(position: .leading, values: yGridValues) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(yGridLabel(for: v))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxisLabel(position: .topLeading) {
                        Text(Temp.unitSymbol(unit))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: chartHeight)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(tempPoints) { point in
                LineMark(
                    x: .value("时间", point.time),
                    y: .value("体温", plotValue(forCelsius: point.celsius))
                )
                .foregroundStyle(Brand.accent.opacity(0.85))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("时间", point.time),
                    y: .value("体温", plotValue(forCelsius: point.celsius))
                )
                .foregroundStyle(Temp.color(for: point.celsius))
                .symbolSize(compact ? 30 : 70)
            }

            ForEach(medPoints) { point in
                RuleMark(x: .value("时间", point.time))
                    .foregroundStyle(Color.blue.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(
                        position: .top,
                        spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        MedicationPillTag(name: point.name, compact: compact)
                    }
            }
        }
        .chartYScale(domain: yDomain)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(compact ? .title3 : .largeTitle)
                .foregroundStyle(.tertiary)
            Text("暂无体温记录")
                .font(compact ? .footnote : .subheadline)
                .foregroundStyle(.secondary)
            if !compact {
                Text("记录体温后,这里会显示体温变化曲线")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: chartHeight)
    }
}

/// 图表顶部的用药标签:完整模式为「药丸图标 + 药名」胶囊,compact 模式仅图标。
private struct MedicationPillTag: View {
    let name: String
    let compact: Bool

    var body: some View {
        if compact {
            Image(systemName: "pills.fill")
                .font(.system(size: 8))
                .foregroundStyle(.blue)
        } else {
            HStack(spacing: 3) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 9))
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(.blue)
            .background(Capsule().fill(Color.blue.opacity(0.12)))
        }
    }
}
