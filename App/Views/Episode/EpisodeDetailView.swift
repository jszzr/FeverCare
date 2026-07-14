import SwiftUI
import SwiftData

/// 病程详情:完整体温图表 + 统计行 + 按时间倒序的事件列表。
/// 点击事件行可编辑,支持滑动删除;工具栏可导出报告,活跃病程可在此结束。
struct EpisodeDetailView: View {
    let episode: Episode

    @Environment(\.modelContext) private var modelContext
    @AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue
    private var unit: TempUnit { TempUnit(rawValue: tempUnitRaw) ?? .celsius }

    @State private var editingEvent: CareEvent?
    @State private var showEndConfirm = false

    init(episode: Episode) {
        self.episode = episode
    }

    private var reversedEvents: [CareEvent] {
        episode.sortedEvents.reversed()
    }

    var body: some View {
        List {
            Section {
                TemperatureChartView(episode: episode)
                    .padding(.vertical, 4)
            }

            Section {
                TimelineView(.everyMinute) { _ in
                    statsRow
                }
            } footer: {
                Text(rangeDescription)
            }

            Section("全部记录") {
                if reversedEvents.isEmpty {
                    Text("还没有任何记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reversedEvents) { event in
                        Button {
                            editingEvent = event
                        } label: {
                            EpisodeEventRow(event: event, unit: unit)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(event)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("病程详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("导出报告") {
                    EpisodeReportView(episode: episode)
                }
            }
            if episode.isActive {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("结束病程") {
                        showEndConfirm = true
                    }
                }
            }
        }
        .confirmationDialog("结束这次病程?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("结束病程", role: .destructive) {
                endEpisode()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("结束后仍可在历史中查看和编辑本次记录。")
        }
        .sheet(item: $editingEvent) { event in
            EventEditSheet(event: event)
        }
    }

    // MARK: - 统计行

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(title: "最高体温", value: maxTempText, valueColor: maxTempColor)
            Divider()
            statCell(title: "持续时长", value: episode.durationDescription, valueColor: .primary)
            Divider()
            statCell(title: "用药次数", value: "\(episode.medicationEvents.count)次", valueColor: .primary)
        }
        .padding(.vertical, 4)
    }

    private var maxTempText: String {
        guard let maxC = episode.maxTemperatureC else { return "--" }
        return Temp.display(maxC, unit: unit)
    }

    private var maxTempColor: Color {
        guard let maxC = episode.maxTemperatureC else { return .secondary }
        return Temp.color(for: maxC)
    }

    private func statCell(title: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var rangeDescription: String {
        let start = Fmt.monthDayTime.string(from: episode.startedAt)
        if let endedAt = episode.endedAt {
            return "开始于 \(start),结束于 \(Fmt.monthDayTime.string(from: endedAt))"
        }
        return "开始于 \(start),进行中"
    }

    // MARK: - 数据操作

    private func delete(_ event: CareEvent) {
        let child = episode.child
        modelContext.delete(event)
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: child?.activeEpisode)
    }

    private func endEpisode() {
        episode.endedAt = Date()
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: episode.child?.activeEpisode)
    }
}

/// 事件列表行:分类图标 + 主文案(+ 备注)+ 时间。
private struct EpisodeEventRow: View {
    let event: CareEvent
    let unit: TempUnit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.kind.symbolName)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(Fmt.monthDayTime.string(from: event.timestamp))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private var iconColor: Color {
        switch event.kind {
        case .temperature:
            if let celsius = event.temperatureC { return Temp.color(for: celsius) }
            return .orange
        case .medication:
            return .blue
        case .cooling:
            return .teal
        case .note:
            return .gray
        }
    }

    private var title: String {
        switch event.kind {
        case .temperature:
            if let celsius = event.temperatureC {
                return "\(Temp.display(celsius, unit: unit)) · \(Temp.levelLabel(for: celsius))"
            }
            return "体温"
        case .medication:
            if let name = event.medicationName, !name.isEmpty {
                return "服用\(name)"
            }
            return "用药"
        case .cooling:
            return "物理降温"
        case .note:
            return "备注"
        }
    }

    private var subtitle: String? {
        event.note
    }
}
