import SwiftUI
import SwiftData

/// 设置页:孩子管理、温度单位、Live Activity 开关、隐私与免责、关于。
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]

    @AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue
    @AppStorage("selectedChildID") private var selectedChildID = ""
    @AppStorage(LiveActivityController.enabledKey) private var liveActivityEnabled = true

    @State private var showingAddChild = false
    @State private var editingChild: Child?
    @State private var childPendingDeletion: Child?
    @State private var showingDeleteDialog = false

    var body: some View {
        NavigationStack {
            Form {
                childrenSection
                unitSection
                liveActivitySection
                iCloudSection
                privacySection
                aboutSection
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showingAddChild) {
                ChildEditSheet(child: nil)
            }
            .sheet(item: $editingChild) { child in
                ChildEditSheet(child: child)
            }
            .confirmationDialog(
                "删除孩子",
                isPresented: $showingDeleteDialog,
                titleVisibility: .visible,
                presenting: childPendingDeletion
            ) { child in
                Button("删除「\(child.name)」及其全部记录", role: .destructive) {
                    delete(child)
                }
                Button("取消", role: .cancel) {}
            } message: { child in
                Text("将永久删除「\(child.name)」的所有病程与护理记录,此操作无法撤销。")
            }
            .onChange(of: liveActivityEnabled) { _, newValue in
                if newValue {
                    LiveActivityController.shared.sync(
                        episode: children.selected(byID: selectedChildID)?.activeEpisode
                    )
                } else {
                    LiveActivityController.shared.sync(episode: nil)
                }
            }
        }
    }

    // MARK: - 孩子管理

    private var childrenSection: some View {
        Section {
            ForEach(children) { child in
                Button {
                    editingChild = child
                } label: {
                    HStack(spacing: 12) {
                        Text(child.emoji)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(child.name)
                                .foregroundStyle(.primary)
                            if let age = child.ageDescription {
                                Text(age)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("删除", role: .destructive) {
                        childPendingDeletion = child
                        showingDeleteDialog = true
                    }
                }
            }

            Button {
                showingAddChild = true
            } label: {
                Label("添加孩子", systemImage: "plus.circle.fill")
                    .foregroundStyle(Brand.accent)
            }
        } header: {
            Text("孩子管理")
        } footer: {
            Text("点按可编辑,左滑可删除;删除孩子会一并删除其全部病程与记录。")
        }
    }

    // MARK: - 温度单位

    private var unitSection: some View {
        Section("温度单位") {
            Picker("温度单位", selection: $tempUnitRaw) {
                ForEach(TempUnit.allCases, id: \.rawValue) { unit in
                    Text(unit.label).tag(unit.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Live Activity

    private var liveActivitySection: some View {
        Section {
            Toggle("锁屏实时显示", isOn: $liveActivityEnabled)
                .tint(Brand.accent)
        } header: {
            Text("实时活动")
        } footer: {
            Text("开启后,病程进行中会在锁屏与灵动岛实时显示最近体温和上次用药时间。")
        }
    }

    // MARK: - iCloud 同步

    private var iCloudSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud 同步")
                    Text("登录 iCloud 后自动开启,无需设置")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "icloud")
                    .foregroundStyle(Brand.accent)
            }
        } header: {
            Text("多设备同步")
        } footer: {
            Text("数据经由你自己的 iCloud 私有空间在你的设备间同步(如爸爸妈妈各自的手机登录同一 Apple 账户)。未登录 iCloud 时数据仅保存在本机。")
        }
    }

    // MARK: - 隐私与免责

    private var privacySection: some View {
        Section("隐私与免责") {
            Text(AppCopy.privacy)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(AppCopy.disclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section("关于") {
            LabeledContent("应用名称", value: AppCopy.appName)
            LabeledContent("版本", value: "0.1.0")
        }
    }

    // MARK: - 操作

    @MainActor
    private func delete(_ child: Child) {
        let deletedID = child.id
        let wasSelected = child.id.uuidString == selectedChildID
        modelContext.delete(child)
        try? modelContext.save()
        if wasSelected {
            selectedChildID = ""
        }
        let remaining = children.filter { $0.id != deletedID }
        LiveActivityController.shared.sync(
            episode: remaining.selected(byID: selectedChildID)?.activeEpisode
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Child.self, inMemory: true)
}
