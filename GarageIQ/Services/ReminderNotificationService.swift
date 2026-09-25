import Foundation
import UserNotifications

enum ReminderNotificationService {
    static func enableAndSchedule(_ reminder: MaintenanceReminder) async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }
            await schedule(reminder)
            return true
        } catch { return false }
    }

    static func schedule(_ reminder: MaintenanceReminder) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        guard reminder.notificationEnabled, !reminder.completed, let date = notificationDate(for: reminder), date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.vehicle.map { "Maintenance is due soon for \($0.year) \($0.make) \($0.model)." } ?? "Maintenance is due soon."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger))
    }

    static func cancel(_ reminder: MaintenanceReminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }

    private static func notificationDate(for reminder: MaintenanceReminder) -> Date? {
        var dates: [Date] = []
        if let due = reminder.dueDate, let alert = Calendar.current.date(byAdding: .day, value: -1, to: due) { dates.append(alert) }
        if let mileage = reminder.dueMileage, let vehicle = reminder.vehicle, let due = vehicle.estimatedDueDate(for: mileage), let alert = Calendar.current.date(byAdding: .day, value: -1, to: due) { dates.append(alert) }
        return dates.min()
    }
}
