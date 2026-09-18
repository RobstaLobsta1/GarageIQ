import SwiftUI
import SwiftData

struct AddMaintenanceRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var form: MaintenanceFormData
    @State private var showValidation = false
    @State private var saveError: String?
    private let vehicle: Vehicle
    private let record: MaintenanceRecord?

    init(vehicle: Vehicle, record: MaintenanceRecord? = nil) {
        self.vehicle = vehicle
        self.record = record
        _form = State(initialValue: MaintenanceFormData(vehicle: vehicle, record: record))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") {
                    Text("\(String(vehicle.year)) \(vehicle.make) \(vehicle.model)")
                    if !vehicle.nickname.isEmpty { Text(vehicle.nickname).foregroundStyle(.secondary) }
                }
                Section("Service") {
                    TextField("Service type", text: $form.serviceType)
                    DatePicker("Date", selection: $form.date, displayedComponents: .date)
                    TextField("Mileage", text: $form.mileage)
                        .keyboardType(.numberPad)
                }
                Section {
                    TextField("Cost (optional)", text: $form.cost)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Shop", text: $form.shop)
                } header: {
                    Text("Cost and shop")
                } footer: {
                    Text("Use a decimal point for cost, such as 89.95. Leave blank if unknown.")
                }
                Section("Notes") {
                    TextField("Notes", text: $form.notes, axis: .vertical)
                        .lineLimit(4...10)
                }
                if showValidation && !form.validationErrors.isEmpty {
                    Section("Please check these fields") {
                        ForEach(form.validationErrors, id: \.self) { Text($0).foregroundStyle(.red) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GarageTheme.background)
            .toolbarBackground(GarageTheme.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle(record == nil ? "Add Service" : "Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .alert("Could Not Save Service", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "Please try again.") }
        }
    }

    private func save() {
        showValidation = true
        guard form.validationErrors.isEmpty, let mileage = form.parsedMileage else { return }
        let savedRecord: MaintenanceRecord
        if let record {
            savedRecord = record
        } else {
            savedRecord = MaintenanceRecord(vehicle: vehicle, serviceType: form.serviceType, mileage: mileage)
            modelContext.insert(savedRecord)
        }
        form.apply(to: savedRecord)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "Your changes could not be saved. \(error.localizedDescription)"
        }
    }
}
