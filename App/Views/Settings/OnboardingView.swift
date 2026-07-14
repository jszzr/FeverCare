import SwiftUI
import SwiftData

/// 首次启动的单页引导:介绍特性 + 创建第一个孩子。
/// 插入 Child 后,RootView 依据 @Query 自动切换到主界面。
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedChildID") private var selectedChildID = ""

    @State private var name = ""
    @State private var hasBirthDate = false
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                features
                childForm
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Brand.pageBackground)
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: - 顶部图标与欢迎语

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "thermometer.variable")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(Brand.accent)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text(AppCopy.appName)
                .font(.largeTitle.bold())
            Text(AppCopy.onboardingWelcome)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 三行特性

    private var features: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingFeatureRow(
                symbol: "internaldrive.fill",
                title: "数据只属于你",
                detail: AppCopy.privacy
            )
            OnboardingFeatureRow(
                symbol: "lock.iphone",
                title: "锁屏实时显示",
                detail: "病程进行中,锁屏与灵动岛实时显示最近体温和上次用药时间。"
            )
            OnboardingFeatureRow(
                symbol: "doc.text.fill",
                title: "一键导出就诊报告",
                detail: "把整段病程整理成医生一眼能读的 PDF 报告,复诊交接不断层。"
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 新建第一个孩子

    private var childForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("先添加一个孩子")
                .font(.subheadline.weight(.semibold))
            TextField("孩子的名字或小名", text: $name)
                .submitLabel(.done)
                .padding(14)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Toggle("填写出生日期(可选)", isOn: $hasBirthDate.animation())
                .font(.subheadline)
                .tint(Brand.accent)
            if hasBirthDate {
                DatePicker(
                    "出生日期",
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .font(.subheadline)
            }
        }
        .padding(20)
        .background(Brand.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 底部按钮与免责

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Button("开始使用") { start() }
                .buttonStyle(BigActionButtonStyle())
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.5 : 1)
            Text(AppCopy.disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Brand.pageBackground)
    }

    private func start() {
        let child = Child(name: trimmedName, birthDate: hasBirthDate ? birthDate : nil)
        modelContext.insert(child)
        try? modelContext.save()
        selectedChildID = child.id.uuidString
    }
}

// MARK: - 特性行

private struct OnboardingFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Brand.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: Child.self, inMemory: true)
}
