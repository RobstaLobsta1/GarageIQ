import Foundation

struct MaintenanceFormData {
    var serviceType = "Oil Change"
    var date = Date.now
    var mileage = ""
    var cost = ""
    var shop = ""
    var notes = ""

    init(vehicle: Vehicle, record: MaintenanceRecord? = nil) {
        mileage = String(vehicle.currentMileage)
        guard let record else { return }
        serviceType = record.serviceType
        date = record.date
        mileage = String(record.mileage)
        cost = record.cost.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        shop = record.shopName
        notes = record.notes
    }

    var parsedMileage: Int? { Int(mileage.trimmingCharacters(in: .whitespacesAndNewlines)) }
    var cleanedCost: String { cost.trimmingCharacters(in: .whitespacesAndNewlines) }
    var parsedCost: Decimal? { Decimal(string: cleanedCost, locale: Locale(identifier: "en_US_POSIX")) }

    var validationErrors: [String] {
        var errors: [String] = []
        if serviceType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Service type is required.")
        }
        if parsedMileage.map({ $0 >= 0 }) != true {
            errors.append("Mileage must be a whole number of zero or greater.")
        }
        if !cleanedCost.isEmpty {
            // Validate the entire input: Decimal(string:) alone can accept a numeric prefix.
            let matches = cleanedCost.range(of: #"^[0-9]{1,12}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil
            if !matches || parsedCost == nil {
                errors.append("Cost must be nonnegative, with up to 12 whole digits and 2 decimal places (for example, 89.95), or left blank.")
            }
        }
        return errors
    }

    func apply(to record: MaintenanceRecord) {
        guard validationErrors.isEmpty, let mileage = parsedMileage else { return }
        record.serviceType = serviceType.trimmingCharacters(in: .whitespacesAndNewlines)
        record.date = date
        record.mileage = mileage
        record.cost = cleanedCost.isEmpty ? nil : parsedCost
        record.shopName = shop.trimmingCharacters(in: .whitespacesAndNewlines)
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
