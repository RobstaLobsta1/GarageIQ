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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estimated driving").font(.headline)
                        if vehicles.filter({ $0.estimatedMilesPerPeriod != nil }).isEmpty {
                            Text("Set your typical weekly or monthly miles in Garage to estimate your odometer automatically.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(vehicles.filter { $0.estimatedMilesPerPeriod != nil }) { vehicle in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vehicle.nickname.isEmpty ? "\(vehicle.make) \(vehicle.model)" : vehicle.nickname).font(.headline)
                                Text("≈ \(vehicle.estimatedMileage(at: context.date).formatted()) miles")
                                    .font(.title2).monospacedDigit()
                                Text("\(vehicle.drivingPurpose ?? "Mixed use") · ≈ \(Int(vehicle.dailyDrivingMiles * 7).formatted()) miles/week · ≈ \(Int(vehicle.dailyDrivingMiles * 30.4375).formatted()) miles/month")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text("Based on your driving profile, not a live odometer reading.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GarageTheme.surface, in: RoundedRectangle(cornerRadius: 20))
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
                    .background(GarageTheme.surface, in: RoundedRectangle(cornerRadius: 20))
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
