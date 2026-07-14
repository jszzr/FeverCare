import SwiftUI
import SwiftData

/// 模块 C:历史病程列表。
/// 展示当前孩子的全部病程(进行中的单独一组),点击进入详情,支持滑动删除(二次确认)。
@MainActor
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]

    @AppStorage("selectedChildID") private var selectedChildID = ""
    @AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue
    private var unit: TempUnit { TempUnit(rawValue: tempUnitRaw) ?? .celsius }

    @State private var episodePendingDeletion: Episode?
    @State private var isDeleteConfirmationPresented = false

    private var child: Child? { children.selected(byID: selectedChildID) }

    var body: some View {
        NavigationStack {
            Group {
                if let child {
                    content(for: child)
                } else {
                    HistoryEmptyPlaceholder(
                        symbolName: "person.crop.circle.badge.questionmark",
                        title: "还没有孩子档案",
                        message: "请先在「设置」中添加孩子。"
                    )
                }
            }
            .navigationTitle("历史病程")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    childSwitcher
                }
            }
            .confirmationDialog(
                "删除这次病程?",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible,
                presenting: episodePendingDeletion
            ) { episode in
                Button("删除病程及其全部记录", role: .destructive) {
                    delete(episode)
                }
                Button("取消", role: .cancel) {}
            } message: { episode in
                Text("将删除 \(Fmt.monthDay.string(from: episode.startedAt)) 开始的这次病程及其全部记录,此操作无法撤销。")
            }
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private func content(for child: Child) -> some View {
        let pastEpisodes = child.pastEpisodes
        let activeEpisode = child.activeEpisode

        if pastEpisodes.isEmpty && activeEpisode == nil {
            HistoryEmptyPlaceholder(
                symbolName: "clock.arrow.circlepath",
                title: "暂无历史病程",
                message: "\(child.name)还没有病程记录。\n在「记录」页开始记录后,这里会按次列出每一段病程。"
            )
        } else {
            List {
                if let activeEpisode {
                    Section("进行中") {
                        episodeRow(activeEpisode)
                    }
                }
                if !pastEpisodes.isEmpty {
                    Section("已结束") {
                        ForEach(pastEpisodes) { episode in
                            episodeRow(episode)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func episodeRow(_ episode: Episode) -> some View {
        NavigationLink {
            EpisodeDetailView(episode: episode)
        } label: {
            EpisodeSummaryRow(episode: episode, unit: unit)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                episodePendingDeletion = episode
                isDeleteConfirmationPresented = true
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - 孩子切换(与 Home 相同模式)

    @ViewBuilder
    private var childSwitcher: some View {
        if let child {
            Menu {
                ForEach(children) { candidate in
                    Button {
                        selectedChildID = candidate.id.uuidString
                    } label: {
                        if candidate.id == child.id {
                            Label("\(candidate.emoji) \(candidate.name)", systemImage: "checkmark")
                        } else {
                            Text("\(candidate.emoji) \(candidate.name)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(child.emoji)
                    Text(child.name)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 删除

    private func delete(_ episode: Episode) {
        let owner = episode.child ?? child
        modelContext.delete(episode)
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: owner?.activeEpisode)
        episodePendingDeletion = nil
    }
}

// MARK: - 单条病程行

/// 一行病程摘要:日期范围、持续时长、最高体温(带分级色)、用药次数。
struct EpisodeSummaryRow: View {
    let episode: Episode
    let unit: TempUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateRangeText)
                    .font(.headline)
                Spacer(minLength: 8)
                if let maxC = episode.maxTemperatureC {
                    Text("最高 \(Temp.display(maxC, unit: unit))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Temp.color(for: maxC))
                } else {
                    Text("未记录体温")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 14) {
                Label(durationText, systemImage: "clock")
                Label("用药\(episode.medicationEvents.count)次", systemImage: "pills")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 6)
    }

    private var dateRangeText: String {
        let start = Fmt.monthDay.string(from: episode.startedAt)
        guard let endedAt = episode.endedAt else {
            return "\(start) 至今"
        }
        let end = Fmt.monthDay.string(from: endedAt)
        return start == end ? start : "\(start) – \(end)"
    }

    private var durationText: String {
        episode.isActive ? "已持续\(episode.durationDescription)" : "持续\(episode.durationDescription)"
    }
}

// MARK: - 空状态占位

/// 插画式空状态(SF Symbol + 文案)。
struct HistoryEmptyPlaceholder: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        }
    }
}
