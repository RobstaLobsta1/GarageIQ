import SwiftUI
import SwiftData

struct UpdateOdometerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    @State private var mileage: String
    @State private var error: String?

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _mileage = State(initialValue: String(vehicle.currentMileage))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") { Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)") }
                Section("Odometer") {
                    TextField("Current mileage", text: $mileage).keyboardType(.numberPad)
                    Text("Each reading helps GarageIQ learn your real driving pattern.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .scrollContentBackground(.hidden).background(GarageTheme.background)
            .navigationTitle("Update Odometer").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        guard let value = Int(mileage), value >= vehicle.currentMileage else {
            error = "Enter a mileage at least as high as the current reading."
            return
        }
        vehicle.confirmMileage(value, at: .now)
        do { try context.save(); dismiss() }
        catch { context.rollback(); self.error = "Could not save the reading. \(error.localizedDescription)" }
    }
}
