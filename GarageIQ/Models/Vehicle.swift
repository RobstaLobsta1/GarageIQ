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
    var odometerHistoryData: Data? = nil
    var drivingHistoryStartDate: Date? = nil

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

    var odometerReadings: [MileageObservation] {
        if let data = odometerHistoryData, let readings = try? JSONDecoder().decode([MileageObservation].self, from: data), !readings.isEmpty { return readings }
        return [MileageObservation(id: id.uuidString, date: odometerConfirmedDate ?? dateAdded,
            mileage: currentMileage, title: "Confirmed odometer", isService: false)]
    }

    func addHistoricalMileage(_ mileage: Int, at date: Date) {
        var readings = odometerReadings
        readings.removeAll {
            Calendar.current.isDate($0.date, inSameDayAs: date) &&
            ($0.title == "Ownership odometer" || $0.id == id.uuidString)
        }
        readings.append(MileageObservation(id: UUID().uuidString, date: date, mileage: mileage,
            title: "Ownership odometer", isService: false))
        readings.sort { $0.date < $1.date }
        odometerHistoryData = try? JSONEncoder().encode(readings)
        drivingHistoryStartDate = min(drivingHistoryStartDate ?? date, date)
    }

    func confirmMileage(_ mileage: Int, at date: Date = .now) {
        var readings = odometerReadings
        if let last = readings.indices.last,
           Calendar.current.isDate(readings[last].date, inSameDayAs: date), readings[last].mileage == mileage {
            readings[last] = MileageObservation(id: readings[last].id, date: date, mileage: mileage,
                title: "Confirmed odometer", isService: false)
        } else {
            readings.append(MileageObservation(id: UUID().uuidString, date: date, mileage: mileage,
                title: "Confirmed odometer", isService: false))
        }
        // Preserve the previous confirmation before replacing the current value.
        odometerHistoryData = try? JSONEncoder().encode(readings)
        currentMileage = mileage
        odometerConfirmedDate = date
    }

    func mileageForecast(at date: Date = .now, mode: MileageForecast.Mode = .automatic) -> MileageForecast {
        let services = maintenanceRecords.map {
            MileageObservation(id: $0.id.uuidString, date: $0.date, mileage: $0.mileage,
                title: $0.serviceType, isService: true, cost: $0.cost)
        }
        return MileageForecast(observations: services + odometerReadings,
            profileDailyMiles: estimatedMilesPerPeriod == nil ? nil : dailyDrivingMiles, mode: mode, now: min(date, .now), trackingStartDate: drivingHistoryStartDate ?? dateAdded)
    }

    func estimatedMileage(at date: Date = .now) -> Int {
        let forecast = mileageForecast(at: date)
        return forecast.mileage(at: date) ?? forecast.baseline?.mileage ?? currentMileage
    }

    func estimatedDueDate(for mileage: Int, now: Date = .now) -> Date? {
        let current = estimatedMileage(at: now)
        guard mileage > current else { return now }
        guard let rate = mileageForecast(at: now).dailyMiles, rate > 0 else { return nil }
        let seconds = Double(mileage - current) / rate * 86_400
        guard seconds < 315_576_000_000 else { return nil }
        return now.addingTimeInterval(seconds)
    }
}
