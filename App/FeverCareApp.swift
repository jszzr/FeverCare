import SwiftUI
import SwiftData

@main
struct FeverCareApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Child.self, Episode.self, CareEvent.self])
    }
}
