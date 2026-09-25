import Foundation

struct VehicleProposal: Codable {
    let operation: String
    let vehicleID: String?
    let nickname: String?
    let year: Int?
    let make: String?
    let model: String?
    let trim: String?
    let currentMileage: Int?
    let vin: String?
    let licensePlate: String?
    let drivingPurpose: String?
    let drivingPeriod: String?
    let estimatedMilesPerPeriod: Int?

    var acquiredDate: String? = nil
    var acquiredMileage: Int? = nil

    var serviceTitle: String? = nil
    var dueDate: String? = nil
    var notes: String? = nil
    var dueMileage: Int? = nil
    var repeatMonths: Int? = nil
    var repeatMiles: Int? = nil

    var serviceDate: String? = nil
    var serviceMileage: Int? = nil
    var serviceCost: String? = nil
    var shopName: String? = nil

    var recordedDate: Date? { parsedDate(serviceDate) }
    var scheduledDate: Date? { parsedDate(dueDate) }
    var parsedAcquiredDate: Date? { parsedDate(acquiredDate) }

    private func parsedDate(_ value: String?) -> Date? {
        guard let dueDate = value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: dueDate), formatter.string(from: date) == dueDate else { return nil }
        return date
    }

    var fields: [(String, String)] {
        if operation == "record" {
            var rows: [(String, String)] = []
            if let serviceTitle { rows.append(("Service", serviceTitle)) }
            if let serviceDate { rows.append(("Service date", serviceDate)) }
            if let serviceMileage { rows.append(("Service odometer", "\(serviceMileage) miles")) }
            rows.append(("Cost", serviceCost.map { "$\($0)" } ?? "Unknown"))
            if let shopName, !shopName.isEmpty { rows.append(("Shop", shopName)) }
            if let notes, !notes.isEmpty { rows.append(("Notes", notes)) }
            return rows
        }
        if operation == "schedule" {
            var rows: [(String, String)] = []
            if let serviceTitle { rows.append(("Service", serviceTitle)) }
            if let dueDate { rows.append(("First due date", dueDate)) }
            if let dueMileage { rows.append(("First due odometer", "\(dueMileage) miles")) }
            if let repeatMonths { rows.append(("Repeat", "Every \(repeatMonths) months")) }
            if let repeatMiles { rows.append(("Repeat distance", "Every \(repeatMiles) miles")) }
            if let notes, !notes.isEmpty { rows.append(("Notes", notes)) }
            return rows
        }
        var rows: [(String, String)] = []
        for (label, value) in [("Nickname", nickname), ("Year", year.map(String.init)), ("Make", make), ("Model", model), ("Trim", trim), ("Odometer", currentMileage.map { "\($0) miles" }), ("VIN", vin), ("License plate", licensePlate), ("Driving use", drivingPurpose), ("Driving period", drivingPeriod), ("Estimated distance", estimatedMilesPerPeriod.map { "\($0) miles" }), ("Acquired", acquiredDate), ("Mileage when acquired", acquiredMileage.map { "\($0) miles" })] {
            if let value { rows.append((label, value.isEmpty ? "(empty)" : value)) }
        }
        return rows
    }

    var hasCompleteVehicleIdentity: Bool {
        operation == "add" && vehicleID == nil && year != nil &&
        make?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        model?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && currentMileage != nil
    }

    var needsRequiredDrivingProfile: Bool {
        hasCompleteVehicleIdentity &&
        (drivingPurpose?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false ||
         drivingPeriod == nil || estimatedMilesPerPeriod == nil)
    }

    var drivingProfileQuestion: String {
        let needsUse = drivingPurpose?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        let needsDistance = drivingPeriod == nil || estimatedMilesPerPeriod == nil
        if needsUse && needsDistance {
            return "Before I add it, how do you mainly use this vehicle, and about how many miles do you drive on a typical day?"
        }
        if needsUse { return "Before I add it, how do you mainly use this vehicle—for example commuting, school, work, errands, or trips?" }
        return "Before I add it, about how many miles do you drive on a typical day?"
    }

    var isValid: Bool {
        if operation == "record" {
            guard vehicleID.flatMap(UUID.init(uuidString:)) != nil,
                  let serviceTitle, !serviceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  serviceTitle.count <= 500, recordedDate != nil,
                  let serviceMileage, (0...10000000).contains(serviceMileage),
                  (shopName?.count ?? 0) <= 500, (notes?.count ?? 0) <= 500 else { return false }
            if let serviceCost {
                guard serviceCost.range(of: #"^[0-9]{1,12}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
                      Decimal(string: serviceCost, locale: Locale(identifier: "en_US_POSIX")) != nil else { return false }
            }
            return dueDate == nil && dueMileage == nil && repeatMonths == nil && repeatMiles == nil && acquiredDate == nil && acquiredMileage == nil && nickname == nil && year == nil && make == nil && model == nil && trim == nil && currentMileage == nil && vin == nil && licensePlate == nil && drivingPurpose == nil && drivingPeriod == nil && estimatedMilesPerPeriod == nil
        }
        guard serviceDate == nil && serviceMileage == nil && serviceCost == nil && shopName == nil else { return false }
        if operation == "schedule" {
            guard vehicleID.flatMap(UUID.init(uuidString:)) != nil,
                  let serviceTitle, !serviceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  serviceTitle.count <= 500, (notes?.count ?? 0) <= 500,
                  dueDate != nil || dueMileage != nil else { return false }
            if dueDate != nil && scheduledDate == nil { return false }
            if let dueMileage, !(0...10000000).contains(dueMileage) { return false }
            if let repeatMonths, (!(1...1200).contains(repeatMonths) || dueDate == nil) { return false }
            if let repeatMiles, (!(1...10000000).contains(repeatMiles) || dueMileage == nil) { return false }
            return acquiredDate == nil && acquiredMileage == nil && nickname == nil && year == nil && make == nil && model == nil && trim == nil && currentMileage == nil && vin == nil && licensePlate == nil && drivingPurpose == nil && drivingPeriod == nil && estimatedMilesPerPeriod == nil
        }
        guard serviceTitle == nil && dueDate == nil && notes == nil && dueMileage == nil && repeatMonths == nil && repeatMiles == nil else { return false }
        if operation == "delete" { return acquiredDate == nil && acquiredMileage == nil && fields.isEmpty && vehicleID.flatMap(UUID.init(uuidString:)) != nil }
        guard ["add", "update"].contains(operation), !fields.isEmpty else { return false }
        if let year, !(1900...(Calendar.current.component(.year, from: .now) + 1)).contains(year) { return false }
        for value in [currentMileage, estimatedMilesPerPeriod, acquiredMileage] { if let value, !(0...10000000).contains(value) { return false } }
        for value in [make, model] { if let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false } }
        for value in [nickname, make, model, trim, vin, licensePlate, drivingPurpose, drivingPeriod] { if let value, value.count > 500 { return false } }
        if (acquiredDate == nil) != (acquiredMileage == nil) { return false }
        if acquiredDate != nil && parsedAcquiredDate == nil { return false }
        if let acquiredMileage, let currentMileage, acquiredMileage > currentMileage { return false }
        if let drivingPeriod, !["Weekly", "Monthly"].contains(drivingPeriod) { return false }
        if estimatedMilesPerPeriod != nil && drivingPeriod == nil { return false }
        if operation == "add" { return vehicleID == nil && year != nil && make != nil && model != nil && currentMileage != nil && drivingPurpose?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && drivingPeriod != nil && estimatedMilesPerPeriod != nil }
        return vehicleID.flatMap(UUID.init(uuidString:)) != nil
    }
}
