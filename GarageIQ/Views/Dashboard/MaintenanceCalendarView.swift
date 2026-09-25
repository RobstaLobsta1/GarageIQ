import SwiftUI
import SwiftData

struct MaintenanceCalendarView: View {
    let now: Date
    @Query(filter: #Predicate<MaintenanceReminder> { !$0.completed }) private var reminders: [MaintenanceReminder]
    // Refresh mileage-derived dates when service readings change.
    @Query private var records: [MaintenanceRecord]
    @State private var selectedDate = Date.now
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
    }

    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let offset = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: offset)
        cells += range.map { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var events: [CalendarMaintenanceEvent] {
        reminders.compactMap { reminder in
            var dates: [(Date, Bool)] = []
            if let date = reminder.dueDate { dates.append((date, false)) }
            if let mileage = reminder.dueMileage, let vehicle = reminder.vehicle {
                let observations = vehicle.odometerReadings + records.filter { $0.vehicle?.id == vehicle.id }.map {
                    MileageObservation(id: $0.id.uuidString, date: $0.date, mileage: $0.mileage,
                        title: $0.serviceType, isService: true)
                }
                let forecast = MileageForecast(observations: observations,
                    profileDailyMiles: vehicle.estimatedMilesPerPeriod == nil ? nil : vehicle.dailyDrivingMiles,
                    now: now, trackingStartDate: vehicle.drivingHistoryStartDate ?? vehicle.dateAdded)
                if let date = forecast.date(for: MileageDeadline(id: reminder.id.uuidString,
                    title: reminder.title, dueDate: nil, dueMileage: mileage)) {
                    dates.append((date, true))
                }
            }
            guard let first = dates.min(by: { $0.0 < $1.0 }) else { return nil }
            return CalendarMaintenanceEvent(reminder: reminder, date: first.0, estimated: first.1)
        }
        .sorted { $0.date == $1.date ? $0.reminder.title < $1.reminder.title : $0.date < $1.date }
    }

    var body: some View {
        let events = events
        let selected = events.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
        let undated = reminders.filter { reminder in !events.contains { $0.id == reminder.id } }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 44) }
                    .accessibilityLabel("Previous month")
                Spacer(minLength: 0)
                Text(monthStart.formatted(.dateTime.month(.wide).year())).font(.subheadline.bold())
                Spacer(minLength: 0)
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 44) }
                    .accessibilityLabel("Next month")
            }
            .foregroundStyle(GarageTheme.accent)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(date, events: events)
                    } else {
                        Color.clear.frame(height: 44).accessibilityHidden(true)
                    }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { legend }
                VStack(alignment: .leading, spacing: 6) { legend }
            }
            .font(.caption2)
            Button("Today") { selectedDate = now }.font(.caption)
            Divider()
            Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline.bold())
            if selected.isEmpty {
                Text(reminders.isEmpty ? "No maintenance scheduled yet." : "No maintenance due on this day.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(selected) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Label(event.reminder.title, systemImage: "wrench.and.screwdriver")
                        .font(.subheadline.bold()).foregroundStyle(GarageTheme.accent)
                    if let vehicle = event.reminder.vehicle {
                        Text(vehicle.nickname.isEmpty ? "\(vehicle.year) \(vehicle.make) \(vehicle.model)" : vehicle.nickname)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let mileage = event.reminder.dueMileage {
                        Text("Due at \(mileage.formatted()) miles").font(.caption).foregroundStyle(.secondary)
                    }
                    if event.estimated {
                        Text("Estimated from driving forecast; date can change with new readings.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if !event.reminder.notes.isEmpty { Text(event.reminder.notes).font(.caption).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(GarageTheme.chrome, in: RoundedRectangle(cornerRadius: 12))
            }
            let overdue = events.filter { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: now) }.count
            if overdue > 0 {
                Text("\(overdue) overdue schedule\(overdue == 1 ? "" : "s"). Review in Reminders.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if !undated.isEmpty {
                Text("Needs a driving forecast").font(.caption.bold())
                ForEach(undated) { reminder in
                    Text("\(reminder.title) · \(reminder.dueMileage.map { "\($0.formatted()) miles" } ?? "No deadline")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Add driving mileage or dated readings to place mileage-only schedules on the calendar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !reminders.isEmpty {
                Text("Manage and complete schedules in Reminders. Repeating services show their next deadline.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var legend: some View {
        Group {
            Label("Scheduled date", systemImage: "circle.fill").foregroundStyle(GarageTheme.accent)
            Label("Mileage estimate", systemImage: "circle.fill").foregroundStyle(.orange)
        }
    }

    private func dayButton(_ date: Date, events: [CalendarMaintenanceEvent]) -> some View {
        let due = events.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let today = calendar.isDate(date, inSameDayAs: now)
        return Button { selectedDate = date } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(today || !due.isEmpty ? .bold : .regular))
                    .minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    if due.contains(where: { !$0.estimated }) { Circle().fill(GarageTheme.accent).frame(width: 5, height: 5) }
                    if due.contains(where: \.estimated) { Circle().fill(.orange).frame(width: 5, height: 5) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .foregroundStyle(.primary)
            .background(selected ? GarageTheme.userBubble : (!due.isEmpty ? GarageTheme.accent.opacity(0.12) : Color.clear), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected || today ? GarageTheme.accent : Color.clear, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))\(today ? ", today" : ""), \(due.count) maintenance schedule\(due.count == 1 ? "" : "s")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func moveMonth(_ offset: Int) {
        if let date = calendar.date(byAdding: .month, value: offset, to: monthStart) { selectedDate = date }
    }
}

private struct CalendarMaintenanceEvent: Identifiable {
    let reminder: MaintenanceReminder
    let date: Date
    let estimated: Bool
    var id: UUID { reminder.id }
}
