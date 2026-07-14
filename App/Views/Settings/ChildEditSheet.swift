import SwiftUI
import SwiftData

/// 新建 / 编辑孩子的 sheet。`child` 为 nil 时表示新建。
struct ChildEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let child: Child?

    @State private var name: String
    @State private var emoji: String
    @State private var hasBirthDate: Bool
    @State private var birthDate: Date

    private static let emojiOptions = ["🧒", "👦", "👧", "👶", "🐣", "🐰", "🐻", "🐱", "🦊", "🐥"]

    init(child: Child?) {
        self.child = child
        _name = State(initialValue: child?.name ?? "")
        _emoji = State(initialValue: child?.emoji ?? "🧒")
        _hasBirthDate = State(initialValue: child?.birthDate != nil)
        _birthDate = State(initialValue: child?.birthDate
            ?? Calendar.current.date(byAdding: .year, value: -2, to: Date())
            ?? Date())
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("姓名") {
                    TextField("孩子的名字或小名", text: $name)
                        .submitLabel(.done)
                }

                Section("头像") {
                    emojiGrid
                }

                Section("出生日期") {
                    Toggle("填写出生日期(可选)", isOn: $hasBirthDate.animation())
                    if hasBirthDate {
                        DatePicker(
                            "出生日期",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle(child == nil ? "添加孩子" : "编辑孩子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Emoji 选择

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(Self.emojiOptions, id: \.self) { option in
                Button {
                    emoji = option
                } label: {
                    Text(option)
                        .font(.system(size: 30))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(option == emoji ? Brand.accent.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(option == emoji ? Brand.accent : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 保存

    @MainActor
    private func save() {
        let resolvedBirthDate = hasBirthDate ? birthDate : nil
        let target: Child
        if let child {
            child.name = trimmedName
            child.emoji = emoji
            child.birthDate = resolvedBirthDate
            target = child
        } else {
            let newChild = Child(name: trimmedName, emoji: emoji, birthDate: resolvedBirthDate)
            modelContext.insert(newChild)
            target = newChild
        }
        try? modelContext.save()
        if let activeEpisode = target.activeEpisode {
            LiveActivityController.shared.sync(episode: activeEpisode)
        }
        dismiss()
    }
}

#Preview {
    ChildEditSheet(child: nil)
        .modelContainer(for: Child.self, inMemory: true)
}
