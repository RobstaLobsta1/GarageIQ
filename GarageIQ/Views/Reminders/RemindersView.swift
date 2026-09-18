import SwiftUI
import SwiftData

struct RemindersView: View {
    @Query(filter: #Predicate<MaintenanceReminder> { !$0.completed })
    private var reminders: [MaintenanceReminder]
    @Query private var vehicles: [Vehicle]
    @State private var showingSchedule = false
    var body: some View {
        NavigationStack {
            ScrollView {
                if !reminders.isEmpty {
                    ScheduledMaintenanceList().padding()
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if reminders.isEmpty {
                        ContentUnavailableView {
                            Label("No Maintenance Scheduled", systemImage: "bell")
                        } description: {
                            Text(vehicles.isEmpty
                                 ? "Add a vehicle in Garage to start scheduling maintenance."
                                 : "Schedule a service by date or mileage to keep track of upcoming maintenance.")
                        } actions: {
                            if !vehicles.isEmpty {
                                Button("Schedule Service") { showingSchedule = true }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(GarageTheme.background)
                .toolbarBackground(GarageTheme.chrome, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationTitle("Reminders")
                .appearanceSettings()
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
