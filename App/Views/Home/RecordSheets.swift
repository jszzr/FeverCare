import SwiftUI
import SwiftData

// MARK: - 记录体温 sheet

@MainActor
struct TemperatureRecordSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue

    let episode: Episode

    @State private var temperatureC = 38.5
    @State private var timestamp = Date()

    private static let presets: [Double] = [36.5, 37.5, 38.0, 38.5, 39.0, 39.5, 40.0]
    private var unit: TempUnit { TempUnit(rawValue: tempUnitRaw) ?? .celsius }

    init(episode: Episode) {
        self.episode = episode
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    bigNumber
                    sliderRow
                    presetChips
                    timeRow
                }
                .padding()
            }
            .background(Brand.pageBackground.ignoresSafeArea())
            .navigationTitle("记录体温")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("保存") { save() }
                    .buttonStyle(BigActionButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    private var bigNumber: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Temp.number(temperatureC, unit: unit))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .foregroundStyle(Temp.color(for: temperatureC))
                Text(Temp.unitSymbol(unit))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(Temp.levelLabel(for: temperatureC))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Temp.color(for: temperatureC))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Temp.color(for: temperatureC).opacity(0.15), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var sliderRow: some View {
        HStack(spacing: 12) {
            Button {
                adjust(by: -0.1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 36))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Brand.accent)

            Slider(value: $temperatureC, in: 34.0...43.0, step: 0.1)
                .tint(Temp.color(for: temperatureC))

            Button {
                adjust(by: 0.1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Brand.accent)
        }
        .padding()
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var presetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.presets, id: \.self) { preset in
                    let selected = abs(temperatureC - preset) < 0.05
                    Button {
                        temperatureC = preset
                    } label: {
                        Text(Temp.number(preset, unit: unit))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(selected ? Color.white : .primary)
                            .background(selected ? Temp.color(for: preset) : Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var timeRow: some View {
        DatePicker("测量时间", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.compact)
            .padding()
            .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func adjust(by delta: Double) {
        let next = ((temperatureC + delta) * 10).rounded() / 10
        temperatureC = min(43.0, max(34.0, next))
    }

    private func save() {
        let value = (temperatureC * 10).rounded() / 10
        let event = CareEvent(kind: .temperature, timestamp: timestamp, temperatureC: value)
        modelContext.insert(event)
        event.episode = episode
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: episode.child?.activeEpisode ?? episode)
        Analytics.shared.track(.eventRecorded, ["kind": CareEventKind.temperature.rawValue])
        dismiss()
    }
}

// MARK: - 记录用药 sheet

@MainActor
struct MedicationRecordSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let episode: Episode

    @State private var medicationName = ""
    @State private var timestamp = Date()
    @State private var note = ""

    init(episode: Episode) {
        self.episode = episode
    }

    /// 快捷药名:本病程用过的 + 常见药名,去重、保持顺序。
    private var quickNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in episode.medicationNames + AppCopy.commonMedicationNames where !name.isEmpty && !seen.contains(name) {
            seen.insert(name)
            result.append(name)
        }
        return result
    }

    private var trimmedName: String {
        medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("药名") {
                    TextField("输入药名", text: $medicationName)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickNames, id: \.self) { name in
                                Button {
                                    medicationName = name
                                } label: {
                                    Text(name)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(trimmedName == name ? Color.white : .primary)
                                        .background(trimmedName == name ? Color.blue : Color(.tertiarySystemFill), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                Section("时间") {
                    DatePicker("服药时间", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                Section("备注(可选)") {
                    TextField("补充信息,如服用方式等", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("记录用药")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("保存") { save() }
                    .buttonStyle(BigActionButtonStyle(tint: .blue))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.4 : 1)
            }
        }
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = CareEvent(
            kind: .medication,
            timestamp: timestamp,
            medicationName: trimmedName,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        modelContext.insert(event)
        event.episode = episode
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: episode.child?.activeEpisode ?? episode)
        Analytics.shared.track(.eventRecorded, ["kind": CareEventKind.medication.rawValue])
        dismiss()
    }
}

// MARK: - 物理降温 / 备注 sheet

@MainActor
struct ExtraRecordSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let episode: Episode
    let kind: CareEventKind

    @State private var note = ""
    @State private var timestamp = Date()

    init(episode: Episode, kind: CareEventKind) {
        self.episode = episode
        self.kind = kind
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 物理降温可以不填文字(记录行为本身);备注必须有内容。
    private var canSave: Bool {
        kind == .cooling || !trimmedNote.isEmpty
    }

    private var placeholder: String {
        kind == .cooling ? "记录你做了什么(可不填)" : "记录症状、精神状态、饮水情况等"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(kind == .cooling ? "降温方式" : "内容") {
                    TextField(placeholder, text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("时间") {
                    DatePicker("时间", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle(kind.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("保存") { save() }
                    .buttonStyle(BigActionButtonStyle(tint: kind == .cooling ? .teal : .indigo))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
            }
        }
    }

    private func save() {
        let event = CareEvent(
            kind: kind,
            timestamp: timestamp,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        modelContext.insert(event)
        event.episode = episode
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: episode.child?.activeEpisode ?? episode)
        Analytics.shared.track(.eventRecorded, ["kind": kind.rawValue])
        dismiss()
    }
}
