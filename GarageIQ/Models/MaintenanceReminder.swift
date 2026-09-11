import Foundation
import SwiftData

@Model
final class MaintenanceReminder {
    @Attribute(.unique) var id: UUID
    var vehicle: Vehicle?
    var title: String
    var dueDate: Date?
    var dueMileage: Int?
    var repeatMonths: Int? = nil
    var repeatMiles: Int? = nil
    var notes: String
    var completed: Bool
    var notificationEnabled: Bool

    init(
        vehicle: Vehicle,
        title: String,
        dueDate: Date? = nil,
        dueMileage: Int? = nil,
        notes: String = "",
        completed: Bool = false,
        notificationEnabled: Bool = false
    ) {
        self.id = UUID()
        self.vehicle = vehicle
        self.title = title
        self.dueDate = dueDate
        self.dueMileage = dueMileage
        self.notes = notes
        self.completed = completed
        self.notificationEnabled = notificationEnabled
    }
}
