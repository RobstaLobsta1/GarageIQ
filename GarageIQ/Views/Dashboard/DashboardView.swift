import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var maintenanceRecords: [MaintenanceRecord]

    @State private var showingSchedule = false

    var body: some View {
        NavigationStack {
            ScrollView {
                // Refresh the month boundary even when this tab remains open overnight.
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    VStack(spacing: 20) {
                    MonthlyMaintenanceCostCard(
                        summary: MonthlyMaintenanceSummary(records: maintenanceRecords, now: context.date),
                        date: context.date
                    )
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Upcoming maintenance").font(.headline)
                        ScheduledMaintenanceList(limit: 3)
                        Button("Schedule Service", systemImage: "plus") { showingSchedule = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingSchedule) { ScheduleMaintenanceView() }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self], inMemory: true)
}
