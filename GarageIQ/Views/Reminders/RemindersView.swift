import SwiftUI
import SwiftData

struct RemindersView: View {
    @State private var showingSchedule = false
    var body: some View {
        NavigationStack {
            ScrollView { ScheduledMaintenanceList().padding() }
                .navigationTitle("Reminders")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Schedule Service", systemImage: "plus") { showingSchedule = true }
                    }
                }
                .sheet(isPresented: $showingSchedule) { ScheduleMaintenanceView() }
        }
    }
}

#Preview {
    RemindersView()
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self, ChatConversation.self], inMemory: true)
}
