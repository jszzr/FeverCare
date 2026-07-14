import SwiftUI
import SwiftData

// MARK: - 记录主页

@MainActor
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]

    @AppStorage("selectedChildID") private var selectedChildID = ""
    @AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue

    @State private var activeSheet: HomeSheet?
    @State private var showEndConfirmation = false

    private var unit: TempUnit { TempUnit(rawValue: tempUnitRaw) ?? .celsius }
    private var child: Child? { children.selected(byID: selectedChildID) }

    var body: some View {
        NavigationStack {
            Group {
                if let child {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let episode = child.activeEpisode {
                                activeContent(episode: episode)
                            } else {
                                idleContent(child: child)
                            }

                            Text(AppCopy.disclaimerShort)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                        .padding()
                    }
                    .background(Brand.pageBackground.ignoresSafeArea())
                } else {
                    ContentUnavailableView(
                        "还没有孩子档案",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("请先在「设置」中添加孩子。")
                    )
                }
            }
            .navigationTitle(AppCopy.appName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    childSwitcher
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if child?.activeEpisode != nil {
                        Button("结束病程") {
                            showEndConfirmation = true
                        }
                    }
                }
            }
            .confirmationDialog("结束当前病程?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
                Button("结束病程", role: .destructive) {
                    endEpisode()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("结束后仍可在「历史」中查看和编辑本次记录。")
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .temperature(let episode):
                    TemperatureRecordSheet(episode: episode)
                case .medication(let episode):
                    MedicationRecordSheet(episode: episode)
                case .cooling(let episode):
                    ExtraRecordSheet(episode: episode, kind: .cooling)
                case .note(let episode):
                    ExtraRecordSheet(episode: episode, kind: .note)
                }
            }
        }
    }

    // MARK: 顶部孩子切换

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
                    Text("\(child.emoji) \(child.name)")
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: 无活跃病程

    @ViewBuilder
    private func idleContent(child: Child) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .padding(.top, 32)
            Text("当前没有进行中的病程")
                .font(.headline)
            Text("孩子发烧时,点击下方按钮开始记录。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)

        Button {
            startEpisode(for: child)
        } label: {
            Label("开始记录发烧", systemImage: "thermometer.variable")
        }
        .buttonStyle(BigActionButtonStyle())

        if let last = child.pastEpisodes.first {
            lastEpisodeSummary(last)
        }
    }

    private func lastEpisodeSummary(_ episode: Episode) -> some View {
        NavigationLink {
            EpisodeDetailView(episode: episode)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("最近一次病程")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(dateRangeText(for: episode))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    if let maxC = episode.maxTemperatureC {
                        Label {
                            Text("最高 \(Temp.display(maxC, unit: unit))")
                        } icon: {
                            Image(systemName: "thermometer.high")
                                .foregroundStyle(Temp.color(for: maxC))
                        }
                    }
                    Label("持续 \(episode.durationDescription)", systemImage: "clock")
                    Label("用药 \(episode.medicationEvents.count)次", systemImage: "pills")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func dateRangeText(for episode: Episode) -> String {
        let start = Fmt.monthDay.string(from: episode.startedAt)
        guard let endedAt = episode.endedAt else { return "\(start) 至今" }
        let end = Fmt.monthDay.string(from: endedAt)
        return start == end ? start : "\(start) – \(end)"
    }

    // MARK: 有活跃病程

    @ViewBuilder
    private func activeContent(episode: Episode) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(spacing: 16) {
                temperatureCard(episode: episode)

                ForEach(episode.medicationNames, id: \.self) { name in
                    if let lastDose = episode.lastDose(of: name) {
                        medicationCard(name: name, lastDoseAt: lastDose.timestamp, now: timeline.date)
                    }
                }
            }
        }

        actionGrid(episode: episode)

        chartCard(episode: episode)
    }

    private func temperatureCard(episode: Episode) -> some View {
        VStack(spacing: 6) {
            if let latest = episode.latestTemperatureEvent, let celsius = latest.temperatureC {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Temp.number(celsius, unit: unit))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Temp.color(for: celsius))
                    Text(Temp.unitSymbol(unit))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(Temp.levelLabel(for: celsius))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Temp.color(for: celsius))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Temp.color(for: celsius).opacity(0.15), in: Capsule())
                Text("\(Fmt.monthDayTime.string(from: latest.timestamp)) 测量")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("尚未记录体温")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            Label("已持续 \(episode.durationDescription)", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func medicationCard(name: String, lastDoseAt: Date, now: Date) -> some View {
        let justNow = now.timeIntervalSince(lastDoseAt) < 60
        return HStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(.blue.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(justNow ? "刚刚服用了「\(name)」" : "距上次服用「\(name)」已过 \(Fmt.hoursMinutes(since: lastDoseAt, to: now))")
                    .font(.body.weight(.medium))
                Text("上次服用:\(Fmt.monthDayTime.string(from: lastDoseAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func actionGrid(episode: Episode) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            Button {
                activeSheet = .temperature(episode)
            } label: {
                Label("记录体温", systemImage: CareEventKind.temperature.symbolName)
            }
            .buttonStyle(BigActionButtonStyle())

            Button {
                activeSheet = .medication(episode)
            } label: {
                Label("记录用药", systemImage: CareEventKind.medication.symbolName)
            }
            .buttonStyle(BigActionButtonStyle(tint: .blue))

            Button {
                activeSheet = .cooling(episode)
            } label: {
                Label("物理降温", systemImage: CareEventKind.cooling.symbolName)
            }
            .buttonStyle(BigActionButtonStyle(tint: .teal))

            Button {
                activeSheet = .note(episode)
            } label: {
                Label("备注", systemImage: CareEventKind.note.symbolName)
            }
            .buttonStyle(BigActionButtonStyle(tint: .indigo))
        }
    }

    private func chartCard(episode: Episode) -> some View {
        NavigationLink {
            EpisodeDetailView(episode: episode)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("体温曲线")
                        .font(.headline)
                    Spacer()
                    Text("查看详情")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                TemperatureChartView(episode: episode, compact: true)
            }
            .padding()
            .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 数据操作

    private func startEpisode(for child: Child) {
        let episode = Episode(startedAt: Date())
        modelContext.insert(episode)
        episode.child = child
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: child.activeEpisode)
        activeSheet = .temperature(episode)
    }

    private func endEpisode() {
        guard let child, let episode = child.activeEpisode else { return }
        episode.endedAt = Date()
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: child.activeEpisode)
    }
}

// MARK: - 首页 sheet 路由

private enum HomeSheet: Identifiable {
    case temperature(Episode)
    case medication(Episode)
    case cooling(Episode)
    case note(Episode)

    var id: String {
        switch self {
        case .temperature: return "temperature"
        case .medication: return "medication"
        case .cooling: return "cooling"
        case .note: return "note"
        }
    }
}
