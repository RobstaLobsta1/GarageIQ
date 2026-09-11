import Foundation

struct MonthlyMaintenanceSummary {
    let total: Decimal
    let recordCount: Int
    let missingCostCount: Int

    init(records: [MaintenanceRecord], now: Date = .now, calendar: Calendar = .current) {
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        let monthlyRecords = records.filter { $0.date >= start && $0.date <= now }
        total = monthlyRecords.reduce(Decimal.zero) { $0 + ($1.cost ?? .zero) }
        recordCount = monthlyRecords.count
        missingCostCount = monthlyRecords.filter { $0.cost == nil }.count
    }
}
