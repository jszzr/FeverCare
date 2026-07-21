import SwiftUI
import SwiftData
import CoreData
import os

@main
struct FeverCareApp: App {
    private static let logger = Logger(subsystem: "com.zhirui.shaotuitui", category: "App")
    private static let cloudKitContainerIdentifier = "iCloud.com.zhirui.shaotuitui"

    /// CloudKit-backed SwiftData store 本身支持离线使用。不能用
    /// `ubiquityIdentityToken` 判断 CloudKit 是否可用——该 token 代表的是
    /// iCloud Drive Documents，而不是 CloudKit 账户状态。
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Child.self, Episode.self, CareEvent.self])
        let cloud = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )

        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-InitializeCloudKitSchema") {
                try initializeDevelopmentCloudKitSchema(configuration: cloud)
            }
            #endif

            let container = try ModelContainer(for: schema, configurations: [cloud])
            logger.info("Using CloudKit-backed store")
            return container
        } catch {
            // CloudKit-backed stores retain a local replica and work offline. Reaching
            // here indicates a configuration/schema problem, not merely no network or
            // no iCloud account; silently changing to another local-only store could
            // make users believe their data is syncing when it is not.
            fatalError("无法创建 CloudKit 数据库: \(error)")
        }
    }

    #if DEBUG
    /// Explicitly creates the development schema on Apple's servers. This path is
    /// opt-in so ordinary debug launches do not repeatedly initialize the schema.
    private static func initializeDevelopmentCloudKitSchema(
        configuration: ModelConfiguration
    ) throws {
        try autoreleasepool {
            let description = NSPersistentStoreDescription(url: configuration.url)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudKitContainerIdentifier
            )
            description.shouldAddStoreAsynchronously = false

            guard let model = NSManagedObjectModel.makeManagedObjectModel(
                for: [Child.self, Episode.self, CareEvent.self]
            ) else {
                throw CocoaError(.persistentStoreInvalidType)
            }

            let persistentContainer = NSPersistentCloudKitContainer(
                name: "FeverCare",
                managedObjectModel: model
            )
            persistentContainer.persistentStoreDescriptions = [description]

            var loadError: Error?
            persistentContainer.loadPersistentStores { _, error in
                loadError = error
            }
            if let loadError {
                throw loadError
            }

            try persistentContainer.initializeCloudKitSchema()
            logger.info("Initialized Development CloudKit schema")

            if let store = persistentContainer.persistentStoreCoordinator.persistentStores.first {
                try persistentContainer.persistentStoreCoordinator.remove(store)
            }
        }
    }
    #endif

    private let container = Self.makeContainer()

    init() {
        _ = PurchaseManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { Analytics.shared.track(.appOpened) }
        }
        .modelContainer(container)
    }
}
