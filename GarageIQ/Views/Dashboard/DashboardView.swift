import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var vehicles: [Vehicle]
    @Query private var maintenanceRecords: [MaintenanceRecord]

    @State private var showingSchedule = false

    var body: some View {
        NavigationStack {
            ScrollView {
                // Refresh the month boundary even when this tab remains open overnight.
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    VStack(spacing: 20) {
                    VehicleStatusCard(vehicles: vehicles, now: context.date)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Upcoming maintenance").font(.headline)
                        MaintenanceCalendarView(now: context.date)
                        Button("Schedule Service", systemImage: "plus") { showingSchedule = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GarageTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    MileageGraphCard(vehicles: vehicles, now: context.date)
                    MonthlyMaintenanceCostCard(
                        summary: MonthlyMaintenanceSummary(records: maintenanceRecords, now: context.date),
                        date: context.date
                    )
                    }
                }
                .padding()
            }
            .background(GarageTheme.background)
            .scrollContentBackground(.hidden)
            .background(GarageTheme.background)
            .toolbarBackground(GarageTheme.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Dashboard")
            .appearanceSettings()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink { ChatView() } label: { Label("Assistant", systemImage: "sparkles") }
                }
            }
            .sheet(isPresented: $showingSchedule) { ScheduleMaintenanceView() }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self, ChatConversation.self], inMemory: true)
}
