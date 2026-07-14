import SwiftUI
import SwiftData
import os

@main
struct FeverCareApp: App {
    private static let logger = Logger(subsystem: "com.zhirui.fevercare", category: "App")

    /// 优先启用 iCloud 私有库同步;不可用时(未登录 iCloud、无 CloudKit 签名权限等)
    /// 自动退回纯本地存储,数据与行为完全一致,只是不跨设备同步。
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Child.self, Episode.self, CareEvent.self])
        // 注意:缺少 iCloud entitlement 或未登录 iCloud 时,CloudKit 镜像会在
        // 后台线程直接崩溃而不是抛错,try/catch 拦不住——必须先探测再启用。
        // ubiquityIdentityToken 仅在「构建带 iCloud 权限 且 设备已登录 iCloud」时非 nil。
        if FileManager.default.ubiquityIdentityToken != nil {
            do {
                let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.zhirui.fevercare"))
                let container = try ModelContainer(for: schema, configurations: [cloud])
                logger.info("Using CloudKit-backed store")
                return container
            } catch {
                logger.error("CloudKit store unavailable, falling back to local-only: \(String(describing: error))")
            }
        } else {
            logger.info("iCloud unavailable (not signed in, or build lacks entitlement); using local store")
        }
        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            fatalError("无法创建本地数据库:\(error)")
        }
    }

    private let container = Self.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
