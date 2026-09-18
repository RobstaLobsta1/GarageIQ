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
                    TextField("Confirmed odometer mileage", text: $form.currentMileage)
                        .keyboardType(.numberPad)
                }
                Section {
                    Toggle("Estimate mileage automatically", isOn: $form.estimateEnabled)
                    if form.estimateEnabled {
                        Picker("Vehicle use", selection: $form.drivingPurpose) {
                            ForEach(["Commuting", "School", "Work / deliveries", "Errands / family", "Leisure / trips", "Mixed use"], id: \.self) { Text($0) }
                        }
                        Picker("Estimate period", selection: $form.drivingPeriod) {
                            Text("Weekly").tag("Weekly")
                            Text("Monthly").tag("Monthly")
                        }
                        TextField("Typical miles per period", text: $form.drivingMiles).keyboardType(.numberPad)
                        Text("Include all driving for this vehicle: round-trip commutes, work miles, errands, and trips.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if vehicle != nil {
                        Toggle("Confirm odometer reading as of today", isOn: $form.confirmOdometer)
                    }
                } header: { Text("Driving profile") } footer: {
                    Text("Enter your typical total miles. Estimates advance automatically with time, even while the app is closed. Monthly estimates use an average 30.44-day month. Vehicle use describes your routine; it does not add extra miles to your total. Confirm an actual odometer reading anytime to correct the estimate.")
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
            .scrollContentBackground(.hidden)
            .background(GarageTheme.background)
            .toolbarBackground(GarageTheme.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        .modelContainer(for: [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self, ChatConversation.self], inMemory: true)
}
