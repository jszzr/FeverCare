import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]

    var body: some View {
        Group {
            if children.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        #if DEBUG
        .task { seedDemoDataIfRequested() }
        #endif
    }

    #if DEBUG
    /// 启动参数 -SeedDemoData:注入演示数据,仅用于开发调试与截图
    private func seedDemoDataIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-SeedDemoData"), children.isEmpty else { return }
        let now = Date()
        let child = Child(name: "小满", emoji: "👧", birthDate: Calendar.current.date(byAdding: .year, value: -3, to: now))
        modelContext.insert(child)

        let past = Episode(startedAt: now.addingTimeInterval(-86400 * 30))
        past.endedAt = now.addingTimeInterval(-86400 * 28)
        modelContext.insert(past)
        past.child = child
        for (offset, temp) in [(-86400.0 * 30, 38.6), (-86400.0 * 29.5, 39.2), (-86400.0 * 29, 38.1), (-86400.0 * 28.2, 36.9)] {
            let e = CareEvent(kind: .temperature, timestamp: now.addingTimeInterval(offset), temperatureC: temp)
            modelContext.insert(e)
            e.episode = past
        }

        let active = Episode(startedAt: now.addingTimeInterval(-3600 * 9))
        modelContext.insert(active)
        active.child = child
        let events: [CareEvent] = [
            CareEvent(kind: .temperature, timestamp: now.addingTimeInterval(-3600 * 9), temperatureC: 38.9),
            CareEvent(kind: .medication, timestamp: now.addingTimeInterval(-3600 * 8.5), medicationName: "布洛芬"),
            CareEvent(kind: .cooling, timestamp: now.addingTimeInterval(-3600 * 8), note: "温水擦拭"),
            CareEvent(kind: .temperature, timestamp: now.addingTimeInterval(-3600 * 7), temperatureC: 38.1),
            CareEvent(kind: .temperature, timestamp: now.addingTimeInterval(-3600 * 5), temperatureC: 37.5),
            CareEvent(kind: .note, timestamp: now.addingTimeInterval(-3600 * 4.5), note: "精神好转,喝了半杯水"),
            CareEvent(kind: .temperature, timestamp: now.addingTimeInterval(-3600 * 3), temperatureC: 38.4),
            CareEvent(kind: .medication, timestamp: now.addingTimeInterval(-3600 * 2.4), medicationName: "对乙酰氨基酚"),
            CareEvent(kind: .temperature, timestamp: now.addingTimeInterval(-3600 * 1.2), temperatureC: 39.1),
            CareEvent(kind: .temperature, timestamp: now.addingTimeInterval(-60 * 18), temperatureC: 38.3),
        ]
        for e in events {
            modelContext.insert(e)
            e.episode = active
        }
        try? modelContext.save()
        LiveActivityController.shared.sync(episode: active)
    }
    #endif
}

struct MainTabView: View {
    @State private var selection = Self.initialTab()

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("记录", systemImage: "thermometer.variable") }
                .tag(0)
            HistoryView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
                .tag(1)
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(2)
        }
        .tint(Brand.accent)
    }

    /// 启动参数 -DemoTab <0|1|2>:直达指定 Tab,仅用于开发调试与截图
    private static func initialTab() -> Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-DemoTab"), i + 1 < args.count, let tab = Int(args[i + 1]) {
            return tab
        }
        #endif
        return 0
    }
}

// MARK: - 当前选中的孩子(跨 Tab 共享)

extension Array where Element == Child {
    /// 按存储的 id 找当前孩子,找不到则退回第一个
    func selected(byID id: String) -> Child? {
        first { $0.id.uuidString == id } ?? first
    }
}
