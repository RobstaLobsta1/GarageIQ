import SwiftUI
import SwiftData

struct MaintenanceView: View {
    @Query(sort: \Vehicle.dateAdded, order: .reverse) private var vehicles: [Vehicle]
    @State private var selectedVehicleID: UUID?

    private var selectedVehicle: Vehicle? {
        vehicles.first(where: { $0.id == selectedVehicleID }) ?? vehicles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vehicle = selectedVehicle {
                    VStack(spacing: 0) {
                        Picker("Vehicle", selection: Binding(
                            get: { selectedVehicle?.id },
                            set: { selectedVehicleID = $0 }
                        )) {
                            ForEach(vehicles) { item in
                                Text("\(item.nickname.isEmpty ? item.make : item.nickname) · \(String(item.year)) \(item.model)")
                                    .tag(Optional(item.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        MaintenanceHistoryView(vehicle: vehicle)
                            .id(vehicle.id)
                    }
                } else {
                    ContentUnavailableView("Add a Vehicle First", systemImage: "car", description: Text("Open Garage to add a vehicle before recording maintenance."))
                }
            }
            .navigationTitle("Maintenance")
        }
    }
}

#Preview {
    MaintenanceView()
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self], inMemory: true)
}
