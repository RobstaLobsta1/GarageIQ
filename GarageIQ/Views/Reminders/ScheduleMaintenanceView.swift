import SwiftUI
import SwiftData

struct ScheduleMaintenanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.dateAdded, order: .reverse) private var vehicles: [Vehicle]
    @State private var vehicleID: UUID?
    @State private var title = "Oil Change"
    @State private var useDate = true
    @State private var dueDate = Date.now
    @State private var useMileage = false
    @State private var dueMileage = ""
    @State private var months = ""
    @State private var miles = ""
    @State private var notes = ""
    @State private var notifications = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if vehicles.isEmpty { Text("Add a vehicle in Garage before scheduling maintenance.").foregroundStyle(.secondary) }
                Section("Service") {
                    Picker("Vehicle", selection: $vehicleID) {
                        Text("Choose vehicle").tag(Optional<UUID>.none)
                        ForEach(vehicles) { vehicle in
                            Text("\(String(vehicle.year)) \(vehicle.make) \(vehicle.model)").tag(Optional(vehicle.id))
                        }
                    }
                    TextField("Service title", text: $title)
                }
                Section {
                    Toggle("Due by date", isOn: $useDate)
                    if useDate {
                        DatePicker("First due", selection: $dueDate, displayedComponents: .date)
                        TextField("Repeat every … months (optional)", text: $months).keyboardType(.numberPad)
                    }
                    Toggle("Due by mileage", isOn: $useMileage)
                    if useMileage {
                        TextField("First due at mileage", text: $dueMileage).keyboardType(.numberPad)
                        TextField("Repeat every … miles (optional)", text: $miles).keyboardType(.numberPad)
                    }
                } header: { Text("Schedule") } footer: {
                    Text("Choose a date, mileage, or both—whichever comes first. Repeat intervals start from the date and current vehicle mileage when you mark the service complete. Leave intervals blank for a one-time service.")
                }
                Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
                Section("Alert") { Toggle("Notify me before service is due", isOn: $notifications) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .scrollContentBackground(.hidden)
            .background(GarageTheme.background)
            .toolbarBackground(GarageTheme.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Schedule Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(vehicles.isEmpty) }
            }
            .onAppear { if vehicleID == nil { vehicleID = vehicles.first?.id } }
        }
    }

    private func save() {
        guard let vehicle = vehicles.first(where: { $0.id == vehicleID }) else { error = "Choose a vehicle in your Garage."; return }
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let monthText = months.trimmingCharacters(in: .whitespacesAndNewlines)
        let mileText = miles.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, useDate || useMileage else { error = "Enter a service title and enable at least one deadline."; return }
        let deadline = Int(dueMileage.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !useMileage || deadline.map({ $0 >= 0 }) == true else { error = "Due mileage must be a nonnegative whole number."; return }
        guard !useDate || monthText.isEmpty || Int(monthText).map({ (1...1200).contains($0) }) == true else { error = "Repeat months must be a whole number from 1 to 1200."; return }
        guard !useMileage || mileText.isEmpty || Int(mileText).map({ (1...10000000).contains($0) }) == true else { error = "Repeat miles must be a whole number from 1 to 10,000,000."; return }
        let reminder = MaintenanceReminder(vehicle: vehicle, title: cleanedTitle, dueDate: useDate ? dueDate : nil, dueMileage: useMileage ? deadline : nil, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        reminder.repeatMonths = useDate ? Int(monthText) : nil
        reminder.repeatMiles = useMileage ? Int(mileText) : nil
        context.insert(reminder)
        do {
            try context.save()
            if notifications {
                reminder.notificationEnabled = true
                Task {
                    let enabled = await ReminderNotificationService.enableAndSchedule(reminder)
                    await MainActor.run { reminder.notificationEnabled = enabled; try? context.save() }
                }
            }
            dismiss()
        }
        catch { context.rollback(); self.error = "Could not save the schedule. \(error.localizedDescription)" }
    }
}
