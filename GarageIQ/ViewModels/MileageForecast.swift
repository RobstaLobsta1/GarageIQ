import Foundation

struct MileageObservation: Identifiable, Codable {
    let id: String
    let date: Date
    let mileage: Int
    let title: String
    let isService: Bool
    var cost: Decimal? = nil
}

struct MileageDeadline: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let dueMileage: Int?
}

struct MileageForecast {
    enum Confidence: String {
        case learning = "Learning"
        case moderate = "Moderate confidence"
        case high = "High confidence"
    }
    enum Mode: String, CaseIterable, Identifiable {
        case automatic = "Automatic"
        case profile = "Driving profile"
        case history = "Recorded history"
        var id: Self { self }
    }

    let observations: [MileageObservation]
    let baseline: MileageObservation?
    let dailyMiles: Double?
    let observedDailyMiles: Double?
    let expectedDailyMiles: Double?
    let source: String
    let warnings: [String]
    let now: Date
    let trackingStart: Date
    let learningDays: Double

    init(observations: [MileageObservation], profileDailyMiles: Double?, mode: Mode = .automatic, now: Date = .now, trackingStartDate: Date? = nil) {
        self.now = now
        let valid = observations.filter { $0.date <= now && $0.mileage >= 0 }.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            // A manual confirmation wins an exact timestamp tie.
            if $0.isService != $1.isService { return $0.isService }
            return $0.id < $1.id
        }
        self.observations = valid
        baseline = valid.last
        let trackingStart = min(now, trackingStartDate ?? valid.first?.date ?? now)
        self.trackingStart = trackingStart
        var warnings: [String] = []
        if valid.count != observations.count {
            warnings.append("Future-dated or invalid readings are excluded from the forecast.")
        }
        let recent = valid.filter { $0.date >= trackingStart && now.timeIntervalSince($0.date) <= 180 * 86_400 }
        let decreases = zip(recent, recent.dropFirst()).contains { $0.mileage > $1.mileage }
        if decreases {
            warnings.append("Recent readings decrease. Check for a mileage typo or odometer correction; history-based rate learning is paused.")
        }
        var learnedRate: Double?
        var learningDays = 0.0
        if !decreases, let last = recent.last,
           let previous = recent.dropLast().last(where: { last.date.timeIntervalSince($0.date) >= 7 * 86_400 }) {
            let days = last.date.timeIntervalSince(previous.date) / 86_400
            let rate = (Double(last.mileage) - Double(previous.mileage)) / days
            if rate.isFinite && (0...1000).contains(rate) { learnedRate = rate; learningDays = days }
            else { warnings.append("Recorded mileage implies unusually high driving; using the profile if available.") }
        }
        let profile = profileDailyMiles.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        observedDailyMiles = learnedRate
        expectedDailyMiles = profile
        if mode == .automatic, let learnedRate {
            // A week of measurements carries half the weight of the starting profile.
            // Longer measured intervals carry more weight, without freezing a forecast
            // after a single unchanged odometer reading.
            let weight = learningDays / (learningDays + 7)
            dailyMiles = profile.map { $0 * (1 - weight) + learnedRate * weight } ?? learnedRate
            source = "Adaptive driving forecast"
        } else if mode != .history, let profile {
            dailyMiles = profile
            source = "Driving profile (awaiting measured history)"
        } else if mode != .profile, let learnedRate {
            dailyMiles = learnedRate
            source = "Recent recorded readings"
        } else {
            dailyMiles = nil
            source = "More readings or a driving profile needed"
        }
        self.warnings = warnings
        self.learningDays = learningDays
    }

    var confidence: Confidence {
        guard dailyMiles != nil else { return .learning }
        if observations.count >= 4, learningDays >= 60 { return .high }
        if observations.count >= 2, learningDays >= 14 { return .moderate }
        return .learning
    }

    func mileageRange(at date: Date) -> ClosedRange<Int>? {
        guard let center = mileage(at: date), let dailyMiles, date >= now else { return nil }
        let days = max(1, date.timeIntervalSince(now) / 86_400)
        let fraction: Double = confidence == .high ? 0.08 : confidence == .moderate ? 0.15 : 0.25
        let spread = max(25, Int((dailyMiles * days * fraction).rounded(.up)))
        return max(0, center - spread)...(center + spread)
    }

    var drivingComparison: String {
        guard let observedDailyMiles, let expectedDailyMiles else {
            return "Learning your routine: add actual readings at least seven days apart."
        }
        let observed = (observedDailyMiles * 7).formatted(.number.precision(.fractionLength(0)))
        let expected = (expectedDailyMiles * 7).formatted(.number.precision(.fractionLength(0)))
        let trend: String
        if expectedDailyMiles == 0 { trend = observedDailyMiles > 0 ? "Driving more than expected" : "Matching your expected driving" }
        else if observedDailyMiles > expectedDailyMiles * 1.2 { trend = "Driving more than expected" }
        else if observedDailyMiles < expectedDailyMiles * 0.8 { trend = "Driving less than expected" }
        else { trend = "Close to your expected driving" }
        return "\(trend): measured ≈ \(observed) mi/week, expected \(expected) mi/week."
    }

    func expectedMileage(at date: Date) -> Int? {
        guard let first = observations.first(where: { $0.date >= trackingStart }), let expectedDailyMiles, date >= first.date else { return nil }
        let result = Double(first.mileage) + date.timeIntervalSince(first.date) / 86_400 * expectedDailyMiles
        guard result.isFinite, result >= 0, result < Double(Int.max) else { return nil }
        return Int(result.rounded(.down))
    }

    func mileage(at date: Date) -> Int? {
        guard let baseline, let dailyMiles, date >= baseline.date else { return nil }
        let days = date.timeIntervalSince(baseline.date) / 86_400
        let mileage = Double(baseline.mileage) + days * dailyMiles
        guard mileage.isFinite, mileage >= 0, mileage < Double(Int.max) else { return nil }
        return Int(mileage.rounded(.down))
    }

    /// Whichever deadline is first, with already reached deadlines placed at Today.
    func date(for deadline: MileageDeadline) -> Date? {
        var dates: [Date] = []
        if let dueDate = deadline.dueDate { dates.append(max(now, dueDate)) }
        if let dueMileage = deadline.dueMileage,
           let current = mileage(at: now) ?? baseline?.mileage {
            if dueMileage <= current { dates.append(now) }
            else if let dailyMiles, dailyMiles > 0 {
                let seconds = (Double(dueMileage) - Double(current)) / dailyMiles * 86_400
                if seconds.isFinite && seconds < 315_576_000_000 { dates.append(now.addingTimeInterval(seconds)) }
            }
        }
        return dates.min()
    }
}
