import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { ChatView() }
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }
            MaintenanceView()
                .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell") }
            GarageView()
                .tabItem { Label("Garage", systemImage: "car") }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self, ChatConversation.self], inMemory: true)
}
