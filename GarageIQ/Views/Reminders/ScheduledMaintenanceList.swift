import SwiftUI
import SwiftData

struct ScheduledMaintenanceList: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<MaintenanceReminder> { !$0.completed }, sort: \MaintenanceReminder.dueDate)
    private var reminders: [MaintenanceReminder]
    @State private var pendingCompletion: MaintenanceReminder?
    @State private var pendingDeletion: MaintenanceReminder?
    @State private var error: String?
    var limit: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if reminders.isEmpty {
                Text("No maintenance scheduled yet.").foregroundStyle(.secondary)
            }
            ForEach(Array(reminders.prefix(limit ?? reminders.count))) { reminder in
                VStack(alignment: .leading, spacing: 6) {
                    Text(reminder.title).font(.headline)
                    if let vehicle = reminder.vehicle {
                        Text("\(String(vehicle.year)) \(vehicle.make) \(vehicle.model)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let date = reminder.dueDate {
                        Text("Due \(date.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundStyle(Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: .now) ? .red : .primary)
                    }
                    if let mileage = reminder.dueMileage {
                        Text("Due at \(mileage.formatted()) miles")
                        if let vehicle = reminder.vehicle {
                            if vehicle.estimatedMilesPerPeriod != nil, let forecast = vehicle.estimatedDueDate(for: mileage) {
                                Text("Estimated mileage due: \(forecast.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(vehicle.estimatedMileage() >= mileage ? "Mileage reached (estimated if enabled)" : "\((mileage - vehicle.estimatedMileage()).formatted()) miles remaining")
                                .font(.caption).foregroundStyle(vehicle.estimatedMileage() >= mileage ? .red : .secondary)
                        }
                    }
                    if let months = reminder.repeatMonths { Text("Repeats every \(months) months").font(.caption) }
                    if let miles = reminder.repeatMiles { Text("Repeats every \(miles.formatted()) miles").font(.caption) }
                    if !reminder.notes.isEmpty { Text(reminder.notes).font(.caption) }
                    HStack {
                        Button("Mark complete") { pendingCompletion = reminder }.buttonStyle(.bordered)
                        Spacer()
                        Button("Delete", role: .destructive) { pendingDeletion = reminder }.buttonStyle(.borderless)
                    }
                }
                Divider()
            }
            if let limit, reminders.count > limit {
                Text("View all \(reminders.count) schedules in Reminders.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Complete this scheduled service?", isPresented: Binding(get: { pendingCompletion != nil }, set: { if !$0 { pendingCompletion = nil } }), titleVisibility: .visible) {
            Button("Mark Complete") { if let reminder = pendingCompletion { complete(reminder) }; pendingCompletion = nil }
            Button("Cancel", role: .cancel) { pendingCompletion = nil }
        } message: { Text("Repeating deadlines advance from today and the estimated mileage (or confirmed odometer if estimates are off); one-time deadlines are cleared. Add a service record separately to track actual work and cost.") }
        .confirmationDialog("Delete this schedule?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let reminder = pendingDeletion { context.delete(reminder); save() }
                pendingDeletion = nil
            }
        }
        .alert("Schedule Could Not Be Updated", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "Please try again.") }
    }

    private func complete(_ reminder: MaintenanceReminder) {
        var nextMileage: Int?
        if let interval = reminder.repeatMiles {
            guard let current = reminder.vehicle?.estimatedMileage() else { error = "This schedule needs a vehicle before it can repeat."; return }
            let result = current.addingReportingOverflow(interval)
            guard !result.overflow else { error = "The next mileage is too large."; return }
            nextMileage = result.partialValue
        }
        var nextDate: Date?
        if let months = reminder.repeatMonths {
            guard let date = Calendar.current.date(byAdding: .month, value: months, to: .now) else { error = "Could not calculate the next date."; return }
            nextDate = date
        }
        if reminder.repeatMonths == nil && reminder.repeatMiles == nil {
            reminder.completed = true
        } else {
            reminder.dueDate = nextDate
            reminder.dueMileage = nextMileage
        }
        save()
    }

    private func save() {
        do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}
