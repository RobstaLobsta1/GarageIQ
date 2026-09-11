import SwiftUI
import SwiftData

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.dateAdded, order: .reverse) private var vehicles: [Vehicle]
    @State private var showingAddVehicle = false
    @State private var vehicleToEdit: Vehicle?
    @State private var vehicleToDelete: Vehicle?
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(vehicles) { vehicle in
                    Button {
                        vehicleToEdit = vehicle
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vehicle.nickname.isEmpty ? "\(vehicle.year) \(vehicle.make) \(vehicle.model)" : vehicle.nickname)
                                .font(.headline)
                            Text("\(String(vehicle.year)) \(vehicle.make) \(vehicle.model) \(vehicle.trim)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if vehicle.estimatedMilesPerPeriod != nil {
                                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                                    Text("≈ \(vehicle.estimatedMileage(at: timeline.date).formatted()) miles estimated")
                                        .font(.headline)
                                }
                                Text("\(vehicle.drivingPurpose ?? "Mixed use") · \(vehicle.estimatedMilesPerPeriod ?? 0) miles / \(vehicle.drivingPeriod == "Monthly" ? "month" : "week")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(vehicle.currentMileage.formatted()) miles confirmed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                    .accessibilityHint("Edit vehicle")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { vehicleToDelete = vehicle }
                        Button("Edit") { vehicleToEdit = vehicle }
                            .tint(.blue)
                    }
                }
            }
            .overlay {
                if vehicles.isEmpty {
                    ContentUnavailableView {
                        Label("Your Garage Is Empty", systemImage: "car")
                    } description: {
                        Text("Add your first vehicle to get started.")
                    } actions: {
                        Button("Add Vehicle") { showingAddVehicle = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Garage")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Vehicle", systemImage: "plus") { showingAddVehicle = true }
                }
            }
            .sheet(isPresented: $showingAddVehicle) { AddVehicleView() }
            .sheet(item: $vehicleToEdit) { vehicle in AddVehicleView(vehicle: vehicle) }
            .confirmationDialog("Delete this vehicle?", isPresented: Binding(
                get: { vehicleToDelete != nil },
                set: { if !$0 { vehicleToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete Vehicle", role: .destructive) {
                    if let vehicle = vehicleToDelete { delete(vehicle) }
                    vehicleToDelete = nil
                }
                Button("Cancel", role: .cancel) { vehicleToDelete = nil }
            } message: {
                Text("This also deletes this vehicle’s saved maintenance records and reminders.")
            }
            .alert("Could Not Delete Vehicle", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "Please try again.")
            }
        }
    }

    private func delete(_ vehicle: Vehicle) {
        modelContext.delete(vehicle)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deleteError = "The vehicle could not be deleted. Please try again. \(error.localizedDescription)"
        }
    }
}

#Preview {
    GarageView()
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self, ChatConversation.self], inMemory: true)
}
