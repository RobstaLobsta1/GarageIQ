import SwiftUI

struct VehicleStatusCard: View {
    let vehicles: [Vehicle]
    let now: Date
    @State private var vehicleID: UUID?
    @State private var updating: Vehicle?

    private var vehicle: Vehicle? { vehicles.first { $0.id == vehicleID } ?? vehicles.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Vehicle status", systemImage: "car.fill").font(.headline)
            if let vehicle {
                Picker("Vehicle", selection: Binding(get: { vehicle.id }, set: { vehicleID = $0 })) {
                    ForEach(vehicles) { Text($0.nickname.isEmpty ? "\($0.year) \($0.make) \($0.model)" : $0.nickname).tag($0.id) }
                }
                Text("\(vehicle.currentMileage.formatted()) miles").font(.title2).bold().monospacedDigit()
                if let confirmed = vehicle.odometerConfirmedDate {
                    Text("Confirmed \(confirmed.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                }
                Button("Update odometer", systemImage: "gauge.with.dots.needle.50percent") { updating = vehicle }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Add a vehicle to start tracking mileage.").foregroundStyle(.secondary)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(GarageTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .sheet(item: $updating) { UpdateOdometerView(vehicle: $0) }
    }
}
