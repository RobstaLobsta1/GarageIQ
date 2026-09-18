import SwiftUI
import SwiftData

@main
struct GarageIQApp: App {
    var body: some Scene {
        WindowGroup {
            StartupView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self, ChatConversation.self])
    }
}
