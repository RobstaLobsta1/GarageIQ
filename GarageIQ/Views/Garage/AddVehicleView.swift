import SwiftUI
import SwiftData

struct AddVehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var form: VehicleFormData
    @State private var showValidation = false
    @State private var saveError: String?
    private let vehicle: Vehicle?

    init(vehicle: Vehicle? = nil) {
        self.vehicle = vehicle
        _form = State(initialValue: VehicleFormData(vehicle: vehicle))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") {
                    TextField("Nickname", text: $form.nickname)
                    TextField("Year", text: $form.year)
                        .keyboardType(.numberPad)
                    TextField("Make", text: $form.make)
                    TextField("Model", text: $form.model)
                    TextField("Trim", text: $form.trim)
                    TextField("Current mileage", text: $form.currentMileage)
                        .keyboardType(.numberPad)
                }
                Section("Optional details") {
                    TextField("VIN", text: $form.vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("License plate", text: $form.licensePlate)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                if showValidation && !form.validationErrors.isEmpty {
                    Section("Please check these fields") {
                        ForEach(form.validationErrors, id: \.self) { message in
                            Text(message).foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .alert("Could Not Save Vehicle", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func save() {
        showValidation = true
        guard form.validationErrors.isEmpty,
              let year = form.parsedYear,
              let mileage = form.parsedMileage else { return }

        // Draft fields only touch the persistent model after validation succeeds.
        let savedVehicle: Vehicle
        if let vehicle {
            savedVehicle = vehicle
        } else {
            savedVehicle = Vehicle(year: year, make: form.make, model: form.model, currentMileage: mileage)
            modelContext.insert(savedVehicle)
        }
        form.apply(to: savedVehicle)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "Your changes could not be saved. Please try again. \(error.localizedDescription)"
        }
    }
}

#Preview {
    AddVehicleView()
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self], inMemory: true)
}
