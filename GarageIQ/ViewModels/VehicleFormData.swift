import Foundation

struct VehicleFormData {
    var nickname = ""
    var year = String(Calendar.current.component(.year, from: .now))
    var make = ""
    var model = ""
    var trim = ""
    var currentMileage = "0"
    var vin = ""
    var licensePlate = ""

    init(vehicle: Vehicle? = nil) {
        guard let vehicle else { return }
        nickname = vehicle.nickname
        year = String(vehicle.year)
        make = vehicle.make
        model = vehicle.model
        trim = vehicle.trim
        currentMileage = String(vehicle.currentMileage)
        vin = vehicle.vin ?? ""
        licensePlate = vehicle.licensePlate ?? ""
    }

    var maximumYear: Int { Calendar.current.component(.year, from: .now) + 1 }
    var parsedYear: Int? { Int(year.trimmingCharacters(in: .whitespacesAndNewlines)) }
    var parsedMileage: Int? { Int(currentMileage.trimmingCharacters(in: .whitespacesAndNewlines)) }

    var validationErrors: [String] {
        var errors: [String] = []
        if make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Make is required.")
        }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Model is required.")
        }
        if parsedYear.map({ (1900...maximumYear).contains($0) }) != true {
            errors.append("Year must be a whole number between 1900 and \(maximumYear).")
        }
        if parsedMileage.map({ $0 >= 0 }) != true {
            errors.append("Mileage must be a whole number of zero or greater.")
        }
        return errors
    }

    func apply(to vehicle: Vehicle) {
        guard validationErrors.isEmpty, let year = parsedYear, let mileage = parsedMileage else { return }
        vehicle.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.year = year
        vehicle.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.trim = trim.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.currentMileage = mileage
        let cleanedVIN = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPlate = licensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.vin = cleanedVIN.isEmpty ? nil : cleanedVIN
        vehicle.licensePlate = cleanedPlate.isEmpty ? nil : cleanedPlate
    }
}
