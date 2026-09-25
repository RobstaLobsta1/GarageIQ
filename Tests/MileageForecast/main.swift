import Foundation

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == expected, "Expected \(expected), got \(actual)", file: file, line: line)
}
func expectNil<T>(_ actual: T?, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == nil, "Expected nil", file: file, line: line)
}

final class MileageForecastTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func reading(_ id: String, daysAgo: Double, mileage: Int, service: Bool = true) -> MileageObservation {
        MileageObservation(id: id, date: now.addingTimeInterval(-daysAgo * 86_400), mileage: mileage, title: id, isService: service)
    }
    func testNewServiceChangesBaselineAndEditingOrDeletingRecalculates() {
        let manual = reading("manual", daysAgo: 20, mileage: 10000, service: false)
        let service = reading("service", daysAgo: 1, mileage: 12000)
        let original = MileageForecast(observations: [manual], profileDailyMiles: 10, now: now)
        let added = MileageForecast(observations: [manual, service], profileDailyMiles: 10, mode: .profile, now: now)
        let edited = MileageForecast(observations: [manual, reading("service", daysAgo: 1, mileage: 12500)], profileDailyMiles: 10, mode: .profile, now: now)
        let deleted = MileageForecast(observations: [manual], profileDailyMiles: 10, now: now)
        expectEqual(original.mileage(at: now), 10200)
        expectEqual(added.mileage(at: now), 12010)
        expectEqual(edited.mileage(at: now), 12510)
        expectEqual(deleted.mileage(at: now), 10200)
    }
    func testHistoricalRecordCannotReplaceNewManualBaseline() {
        let old = reading("old", daysAgo: 30, mileage: 9000)
        let manual = reading("manual", daysAgo: 0, mileage: 12000, service: false)
        let forecast = MileageForecast(observations: [manual, old], profileDailyMiles: nil, now: now)
        expectEqual(forecast.baseline?.id, "manual")
        expectEqual(forecast.dailyMiles, 100)
        expectEqual(forecast.mileage(at: now.addingTimeInterval(10 * 86_400)), 13000)
    }
    func testProfileOverrideAndSparseHistory() {
        let samples = [reading("old", daysAgo: 10, mileage: 1000), reading("new", daysAgo: 0, mileage: 2000)]
        expectEqual(MileageForecast(observations: samples, profileDailyMiles: 20, now: now).dailyMiles, 20 * (1 - 10.0 / 17) + 100 * (10.0 / 17))
        expectEqual(MileageForecast(observations: samples, profileDailyMiles: 20, mode: .profile, now: now).dailyMiles, 20)
        let sparse = MileageForecast(observations: [reading("one", daysAgo: 0, mileage: 1000)], profileDailyMiles: nil, now: now)
        expectNil(sparse.dailyMiles)
        expectNil(sparse.mileage(at: now.addingTimeInterval(86_400)))
    }
    func testDrivingInputOverridesStaticHistoryAndChangesForecast() {
        let samples = [reading("old", daysAgo: 30, mileage: 20000), reading("new", daysAgo: 0, mileage: 20000)]
        let weekly = MileageForecast(observations: samples, profileDailyMiles: 350.0 / 7, mode: .profile, now: now)
        let increased = MileageForecast(observations: samples, profileDailyMiles: 700.0 / 7, mode: .profile, now: now)
        let monthly = MileageForecast(observations: samples, profileDailyMiles: 900.0 / 30.4375, mode: .profile, now: now)
        let end = now.addingTimeInterval(30 * 86_400)
        expectEqual(weekly.mileage(at: end), 21500)
        expectEqual(increased.mileage(at: end), 23000)
        expectEqual(monthly.mileage(at: now.addingTimeInterval(61 * 86_400)), 21803)
        expectEqual(weekly.source, "Driving profile (awaiting measured history)")
        let history = MileageForecast(observations: samples, profileDailyMiles: 50, mode: .history, now: now)
        expectEqual(history.mileage(at: end), 20000)
        let zero = MileageForecast(observations: samples, profileDailyMiles: 0, now: now)
        expectEqual(zero.mileage(at: end), 20000)
    }
    func testAdaptiveRateAndTrackingStart() {
        let initial = reading("first", daysAgo: 1, mileage: 20000, service: false)
        let fresh = MileageForecast(observations: [initial], profileDailyMiles: 50, now: now)
        expectEqual(fresh.trackingStart, initial.date)
        expectEqual(fresh.dailyMiles, 50)
        let previousOwner = reading("previous owner", daysAgo: 90, mileage: 18000)
        let acquired = MileageForecast(observations: [previousOwner, initial], profileDailyMiles: 50, now: now, trackingStartDate: initial.date)
        expectEqual(acquired.trackingStart, initial.date)
        expectNil(acquired.observedDailyMiles)
        expectEqual(acquired.expectedMileage(at: now), 20050)
        let samples = [reading("first", daysAgo: 14, mileage: 20000, service: false), reading("second", daysAgo: 7, mileage: 20350, service: false), reading("third", daysAgo: 0, mileage: 21050)]
        let adapted = MileageForecast(observations: samples, profileDailyMiles: 50, now: now)
        expectEqual(adapted.observedDailyMiles, 100)
        expectEqual(adapted.dailyMiles, 75)
        expectEqual(adapted.expectedMileage(at: now), 20700)
        expectEqual(adapted.mileage(at: now), 21050)
        expectEqual(adapted.mileage(at: now.addingTimeInterval(7 * 86_400)), 21575)
        precondition(adapted.drivingComparison.contains("more than expected"))
        let stopped = MileageForecast(observations: [reading("a", daysAgo: 30, mileage: 20000), reading("b", daysAgo: 0, mileage: 20000)], profileDailyMiles: 50, now: now)
        precondition(stopped.dailyMiles! > 0 && stopped.dailyMiles! < 50)
        precondition(stopped.drivingComparison.contains("less than expected"))
        let restored = MileageForecast(observations: Array(samples.dropLast()), profileDailyMiles: 50, now: now)
        expectEqual(restored.dailyMiles, 50)
        let data = try! JSONEncoder().encode(samples)
        let persisted = try! JSONDecoder().decode([MileageObservation].self, from: data)
        expectEqual(persisted.map(\.mileage), samples.map(\.mileage))
    }
    func testBadReadingsAndCorrectionsDoNotCreateFalseRates() {
        let samples = [reading("old", daysAgo: 10, mileage: 2000), reading("corrected", daysAgo: 0, mileage: 1000), reading("future", daysAgo: -1, mileage: 3000)]
        let forecast = MileageForecast(observations: samples, profileDailyMiles: 30, now: now)
        expectEqual(forecast.baseline?.id, "corrected")
        expectEqual(forecast.dailyMiles, 30)
        expectEqual(forecast.warnings.count, 2)
        let close = MileageForecast(observations: [reading("a", daysAgo: 1, mileage: 100), reading("b", daysAgo: 0, mileage: 200)], profileDailyMiles: nil, now: now)
        expectNil(close.dailyMiles)
        let extreme = MileageForecast(observations: [reading("a", daysAgo: 10, mileage: 0), reading("b", daysAgo: 0, mileage: 100000)], profileDailyMiles: nil, now: now)
        expectNil(extreme.dailyMiles)
    }
    func testDeadlineWhicheverFirstAndZeroDriving() {
        let forecast = MileageForecast(observations: [reading("base", daysAgo: 0, mileage: 1000)], profileDailyMiles: 10, now: now)
        let date = now.addingTimeInterval(20 * 86_400)
        let both = MileageDeadline(id: "both", title: "Oil", dueDate: date, dueMileage: 1100)
        expectEqual(forecast.date(for: both), now.addingTimeInterval(10 * 86_400))
        expectEqual(forecast.date(for: MileageDeadline(id: "past", title: "Oil", dueDate: now.addingTimeInterval(-86_400), dueMileage: 2000)), now)
        let stopped = MileageForecast(observations: [reading("base", daysAgo: 0, mileage: 1000)], profileDailyMiles: 0, now: now)
        expectEqual(stopped.mileage(at: date), 1000)
        expectNil(stopped.date(for: MileageDeadline(id: "miles", title: "Oil", dueDate: nil, dueMileage: 1100)))
        expectEqual(stopped.date(for: both), date)
    }
    func testMissingAndOverflowData() {
        let empty = MileageForecast(observations: [], profileDailyMiles: nil, now: now)
        expectNil(empty.baseline)
        let huge = MileageForecast(observations: [reading("base", daysAgo: 0, mileage: Int.max)], profileDailyMiles: 10, now: now)
        expectNil(huge.mileage(at: now.addingTimeInterval(86_400)))
        let invalid = MileageForecast(observations: [reading("base", daysAgo: 0, mileage: 100)], profileDailyMiles: .infinity, now: now)
        expectNil(invalid.dailyMiles)
        let ordinary = MileageForecast(observations: [reading("base", daysAgo: 0, mileage: 100)], profileDailyMiles: 10, now: now)
        expectNil(ordinary.mileage(at: now.addingTimeInterval(-86_400)))
    }
    func testConfidenceAndUncertaintyImproveWithHistory() {
        let learning = MileageForecast(observations: [reading("now", daysAgo: 0, mileage: 1000)], profileDailyMiles: 20, now: now)
        expectEqual(learning.confidence, .learning)
        let moderate = MileageForecast(observations: [reading("old", daysAgo: 20, mileage: 1000), reading("now", daysAgo: 0, mileage: 1400)], profileDailyMiles: 20, now: now)
        expectEqual(moderate.confidence, .moderate)
        let high = MileageForecast(observations: [reading("a", daysAgo: 180, mileage: 1000), reading("b", daysAgo: 120, mileage: 1600), reading("c", daysAgo: 60, mileage: 2200), reading("d", daysAgo: 0, mileage: 2800)], profileDailyMiles: 20, now: now)
        expectEqual(high.confidence, .high)
        let future = now.addingTimeInterval(30 * 86_400)
        precondition(high.mileageRange(at: future)!.count < learning.mileageRange(at: future)!.count)
    }
}
let suite = MileageForecastTests()
suite.testNewServiceChangesBaselineAndEditingOrDeletingRecalculates()
suite.testHistoricalRecordCannotReplaceNewManualBaseline()
suite.testProfileOverrideAndSparseHistory()
suite.testDrivingInputOverridesStaticHistoryAndChangesForecast()
suite.testBadReadingsAndCorrectionsDoNotCreateFalseRates()
suite.testDeadlineWhicheverFirstAndZeroDriving()
suite.testMissingAndOverflowData()
suite.testAdaptiveRateAndTrackingStart()
suite.testConfidenceAndUncertaintyImproveWithHistory()
print("9 mileage forecast tests passed")
