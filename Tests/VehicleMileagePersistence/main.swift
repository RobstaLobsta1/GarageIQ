import Foundation
import SwiftData

@MainActor func verifyPersistence() throws {
    let store = URL(fileURLWithPath: CommandLine.arguments[1])
    let schema = Schema([Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self])
    let configuration = ModelConfiguration(schema: schema, url: store)
    let now = Date.now
    let first = now.addingTimeInterval(-14 * 86_400)
    func create() throws {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let vehicle = Vehicle(year: 2024, make: "Honda", model: "Civic", currentMileage: 20000, dateAdded: first)
        vehicle.estimatedMilesPerPeriod = 350
        vehicle.drivingPeriod = "Weekly"
        vehicle.drivingPurpose = "School"
        context.insert(vehicle)
        // Simulates user-provided acquisition history followed by today's odometer.
        vehicle.confirmMileage(21400, at: now)
        vehicle.addHistoricalMileage(20000, at: first)
        precondition(vehicle.odometerReadings.count == 2)
        precondition(vehicle.odometerReadings.first!.mileage == 20000)
        try context.save()
    }
    try create()
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    let vehicle = try context.fetch(FetchDescriptor<Vehicle>()).first!
    precondition(vehicle.odometerReadings.count == 2)
    precondition(vehicle.drivingHistoryStartDate == first)
    precondition(vehicle.currentMileage == 21400)
    precondition(vehicle.mileageForecast(at: now).observedDailyMiles == 100)
    precondition(vehicle.estimatedMileage(at: now) == 21400)
    var form = VehicleFormData(vehicle: vehicle)
    precondition(form.validationErrors.isEmpty)
    let legacyJSON = #"{"operation":"add","vehicleID":null,"nickname":null,"year":2025,"make":"Honda","model":"Civic","trim":null,"currentMileage":1200,"vin":null,"licensePlate":null,"drivingPurpose":null,"drivingPeriod":null,"estimatedMilesPerPeriod":null}"#.data(using: .utf8)!
    let legacyProposal = try JSONDecoder().decode(VehicleProposal.self, from: legacyJSON)
    precondition(legacyProposal.hasCompleteVehicleIdentity)
    precondition(legacyProposal.needsRequiredDrivingProfile)
    precondition(!legacyProposal.isValid)
    precondition(legacyProposal.drivingProfileQuestion.contains("typical day"))
    let completeJSON = #"{"operation":"add","vehicleID":null,"nickname":null,"year":2025,"make":"Honda","model":"Civic","trim":null,"currentMileage":1200,"vin":null,"licensePlate":null,"drivingPurpose":"School","drivingPeriod":"Weekly","estimatedMilesPerPeriod":100}"#.data(using: .utf8)!
    let completeProposal = try JSONDecoder().decode(VehicleProposal.self, from: completeJSON)
    precondition(completeProposal.isValid)
    precondition(!completeProposal.needsRequiredDrivingProfile)
    let historyJSON = #"{"operation":"add","vehicleID":null,"nickname":null,"year":2025,"make":"Dodge","model":"Challenger","trim":null,"currentMileage":15000,"vin":null,"licensePlate":null,"drivingPurpose":"Mixed use","drivingPeriod":"Weekly","estimatedMilesPerPeriod":163,"acquiredDate":"2025-09-24","acquiredMileage":6500}"#.data(using: .utf8)!
    let historyProposal = try JSONDecoder().decode(VehicleProposal.self, from: historyJSON)
    precondition(historyProposal.isValid)
    precondition(historyProposal.parsedAcquiredDate != nil)
    precondition(historyProposal.acquiredMileage == 6500)
    form.drivingPurpose = ""
    precondition(!form.validationErrors.isEmpty)
    form.drivingPurpose = "School"
    form.drivingMiles = ""
    precondition(!form.validationErrors.isEmpty)
    let record = MaintenanceRecord(vehicle: vehicle, serviceType: "Oil", date: now.addingTimeInterval(-7 * 86_400), mileage: 20350)
    context.insert(record)
    try context.save()
    precondition(vehicle.currentMileage == 21400)
    precondition(vehicle.mileageForecast(at: now).observedDailyMiles == 150)
    context.delete(record)
    try context.save()
    precondition(vehicle.mileageForecast(at: now).observedDailyMiles == 100)
    print("Vehicle mileage persistence, proposal compatibility, required profile, and service recalculation checks passed")
}
try MainActor.assumeIsolated { try verifyPersistence() }
