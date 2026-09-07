import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
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
}
