import SwiftUI
import SwiftData

/// 编辑单条护理记录:按 kind 编辑对应字段与时间,可删除本条。
/// 保存/删除后遵循「save + sync」约定。
struct EventEditSheet: View {
    let event: CareEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue
    private var unit: TempUnit { TempUnit(rawValue: tempUnitRaw) ?? .celsius }

    @State private var timestamp: Date
    @State private var temperatureC: Double
    @State private var medicationName: String
    @State private var noteText: String
    @State private var showDeleteConfirm = false

    init(event: CareEvent) {
        self.event = event
        _timestamp = State(initialValue: event.timestamp)
        _temperatureC = State(initialValue: event.temperatureC ?? 38.5)
        _medicationName = State(initialValue: event.medicationName ?? "")
        _noteText = State(initialValue: event.note ?? "")
    }

    private static let quickTemps: [Double] = [36.5, 37.5, 38.0, 38.5, 39.0, 39.5, 40.0]

    /// 药名快捷 chips:本病程用过的药名 + 常见药名,去重、保持顺序。
    private var medicationChips: [String] {
        var seen = Set<String>()
        var chips: [String] = []
        for name in (event.episode?.medicationNames ?? []) + AppCopy.commonMedicationNames {
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            chips.append(name)
        }
        return chips
    }

    private var canSave: Bool {
        if event.kind == .medication {
            return !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                switch event.kind {
                case .temperature:
                    temperatureSection
                case .medication:
                    medicationSection
                case .cooling, .note:
                    noteSection
                }

                Section {
                    DatePicker("时间", selection: $timestamp, in: ...Date())
                        .datePickerStyle(.compact)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除这条记录", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("编辑\(event.kind.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("删除这条记录?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    deleteEvent()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后不可恢复。")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 分类编辑区

    private var temperatureSection: some View {
        Section("体温") {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Temp.number(temperatureC, unit: unit))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(Temp.color(for: temperatureC))
                        .contentTransition(.numericText())
                    Text(Temp.unitSymbol(unit))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    Button {
                        adjustTemperature(by: -0.1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Slider(value: $temperatureC, in: 34.0...43.0, step: 0.1)

                    Button {
                        adjustTemperature(by: 0.1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.quickTemps, id: \.self) { value in
                            Button {
                                temperatureC = value
                            } label: {
                                Text(Temp.display(value, unit: unit))
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(
                                            abs(temperatureC - value) < 0.05
                                                ? Temp.color(for: value).opacity(0.25)
                                                : Color(.tertiarySystemFill)
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var medicationSection: some View {
        Section("用药") {
            TextField("药品名称", text: $medicationName)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(medicationChips, id: \.self) { name in
                        Button {
                            medicationName = name
                        } label: {
                            Text(name)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        medicationName == name
                                            ? Color.blue.opacity(0.2)
                                            : Color(.tertiarySystemFill)
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            TextField("备注(可选)", text: $noteText, axis: .vertical)
                .lineLimit(1...3)
        }
    }

    private var noteSection: some View {
        Section(event.kind == .cooling ? "物理降温" : "备注") {
            TextField(
                event.kind == .cooling ? "降温方式或说明(可选)" : "备注内容",
                text: $noteText,
                axis: .vertical
            )
            .lineLimit(2...6)
        }
    }

    // MARK: - 操作

    private func adjustTemperature(by delta: Double) {
        let next = ((temperatureC + delta) * 10).rounded() / 10
        temperatureC = min(43.0, max(34.0, next))
    }

    private func save() {
        event.timestamp = timestamp
        switch event.kind {
        case .temperature:
            event.temperatureC = (temperatureC * 10).rounded() / 10
        case .medication:
            event.medicationName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
            event.note = trimmedOrNil(noteText)
        case .cooling, .note:
            event.note = trimmedOrNil(noteText)
        }
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: event.episode?.child?.activeEpisode)
        dismiss()
    }

    private func deleteEvent() {
        let child = event.episode?.child
        modelContext.delete(event)
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: child?.activeEpisode)
        dismiss()
    }

    private func trimmedOrNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
