import SwiftUI
import SwiftData

@main
struct GarageIQApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self, ChatConversation.self])
    }
}
