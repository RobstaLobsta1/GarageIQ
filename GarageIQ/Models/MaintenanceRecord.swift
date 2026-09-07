import Foundation
import SwiftData

@Model
final class MaintenanceRecord {
    @Attribute(.unique) var id: UUID
    var vehicle: Vehicle?
    var serviceType: String
    var date: Date
    var mileage: Int
    var cost: Decimal?
    var shopName: String
    var notes: String

    init(
        vehicle: Vehicle,
        serviceType: String,
        date: Date = .now,
        mileage: Int,
        cost: Decimal? = nil,
        shopName: String = "",
        notes: String = ""
    ) {
        self.id = UUID()
        self.vehicle = vehicle
        self.serviceType = serviceType
        self.date = date
        self.mileage = mileage
        self.cost = cost
        self.shopName = shopName
        self.notes = notes
    }
}
