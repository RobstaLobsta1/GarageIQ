import Foundation
import SwiftData

@Model
final class Vehicle {
    @Attribute(.unique) var id: UUID
    var nickname: String
    var year: Int
    var make: String
    var model: String
    var trim: String
    var currentMileage: Int
    var vin: String?
    var licensePlate: String?
    var dateAdded: Date

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRecord.vehicle)
    var maintenanceRecords: [MaintenanceRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceReminder.vehicle)
    var maintenanceReminders: [MaintenanceReminder] = []

    init(
        nickname: String = "",
        year: Int,
        make: String,
        model: String,
        trim: String = "",
        currentMileage: Int = 0,
        vin: String? = nil,
        licensePlate: String? = nil,
        dateAdded: Date = .now
    ) {
        self.id = UUID()
        self.nickname = nickname
        self.year = year
        self.make = make
        self.model = model
        self.trim = trim
        self.currentMileage = currentMileage
        self.vin = vin
        self.licensePlate = licensePlate
        self.dateAdded = dateAdded
    }
}
