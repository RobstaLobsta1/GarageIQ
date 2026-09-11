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
    var estimatedMilesPerPeriod: Int? = nil
    var drivingPeriod: String? = nil
    var drivingPurpose: String? = nil
    var estimateStartDate: Date? = nil
    var estimateStartMileage: Int? = nil
    var odometerConfirmedDate: Date? = nil

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

extension Vehicle {
    var dailyDrivingMiles: Double {
        guard let miles = estimatedMilesPerPeriod else { return 0 }
        return Double(miles) / (drivingPeriod == "Monthly" ? 30.4375 : 7)
    }

    func estimatedMileage(at date: Date = .now) -> Int {
        guard estimatedMilesPerPeriod != nil, let start = estimateStartDate else { return currentMileage }
        let baseline = estimateStartMileage ?? currentMileage
        let days = max(0, date.timeIntervalSince(start) / 86_400)
        let projected = Double(baseline) + days * dailyDrivingMiles
        guard projected.isFinite, projected < Double(Int.max) else { return Int.max }
        return max(baseline, Int(projected.rounded(.down)))
    }

    func estimatedDueDate(for mileage: Int, now: Date = .now) -> Date? {
        let current = estimatedMileage(at: now)
        guard mileage > current else { return now }
        guard dailyDrivingMiles > 0 else { return nil }
        let seconds = Double(mileage - current) / dailyDrivingMiles * 86_400
        guard seconds < 315_576_000_000 else { return nil }
        return now.addingTimeInterval(seconds)
    }
}
