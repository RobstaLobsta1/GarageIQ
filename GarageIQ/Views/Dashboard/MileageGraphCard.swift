import SwiftUI
import SwiftData
import Charts

struct MileageGraphCard: View {
    let vehicles: [Vehicle]
    let now: Date
    // Explicit queries make record edits/deletions refresh the derived forecast.
    @Query private var records: [MaintenanceRecord]
    @Query(filter: #Predicate<MaintenanceReminder> { !$0.completed }) private var reminders: [MaintenanceReminder]
    @State private var vehicleID: UUID?
    @State private var months = 3
    @State private var mode = MileageForecast.Mode.automatic
    @State private var editingVehicle: Vehicle?
    @State private var selectedDate: Date?

    private var vehicle: Vehicle? { vehicles.first { $0.id == vehicleID } ?? vehicles.first }
    private var window: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .month, value: months, to: now) ?? now.addingTimeInterval(90 * 86_400)
        return now...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Mileage & maintenance", systemImage: "chart.xyaxis.line")
                .font(.headline)
            if let vehicle {
                Picker("Vehicle", selection: Binding(get: { vehicle.id }, set: { vehicleID = $0; selectedDate = nil })) {
                    ForEach(vehicles) { item in
                        Text(item.nickname.isEmpty ? "\(item.year) \(item.make) \(item.model)" : item.nickname).tag(item.id)
                    }
                }
                Picker("Forecast horizon", selection: $months) {
                    Text("3 months").tag(3)
                    Text("6 months").tag(6)
                    Text("1 year").tag(12)
                }
                .pickerStyle(.segmented)
                Picker("Forecast rate", selection: $mode) {
                    ForEach(MileageForecast.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                Button(vehicle.estimatedMilesPerPeriod == nil ? "Set driving mileage" : "Edit driving mileage", systemImage: "pencil") {
                    editingVehicle = vehicle
                }
                graph(for: vehicle)
            } else {
                Text("Add a vehicle in Garage to see its mileage and maintenance timeline.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GarageTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .sheet(item: $editingVehicle) { AddVehicleView(vehicle: $0) }
        .onChange(of: vehicle?.id) { _, _ in selectedDate = nil }
        .onChange(of: months) { _, _ in selectedDate = nil }
        .onChange(of: mode) { _, _ in selectedDate = nil }
    }

    private func forecast(for vehicle: Vehicle) -> MileageForecast {
        var observations = records.filter { $0.vehicle?.id == vehicle.id }.map {
            MileageObservation(id: $0.id.uuidString, date: $0.date, mileage: $0.mileage,
                               title: $0.serviceType, isService: true, cost: $0.cost)
        }
        observations.append(contentsOf: vehicle.odometerReadings)
        return MileageForecast(observations: observations,
            profileDailyMiles: vehicle.estimatedMilesPerPeriod == nil ? nil : vehicle.dailyDrivingMiles,
            mode: mode, now: now, trackingStartDate: vehicle.drivingHistoryStartDate ?? vehicle.dateAdded)
    }

    @ViewBuilder private func graph(for vehicle: Vehicle) -> some View {
        let forecast = forecast(for: vehicle)
        let history = forecast.observations.filter { window.contains($0.date) }
        let deadlines = reminders.filter { $0.vehicle?.id == vehicle.id }.map {
            MileageDeadline(id: $0.id.uuidString, title: $0.title, dueDate: $0.dueDate, dueMileage: $0.dueMileage)
        }
        let upcoming = deadlines.compactMap { deadline -> GraphEvent? in
            guard let date = forecast.date(for: deadline), window.contains(date),
                  let mileage = forecast.mileage(at: date) else { return nil }
            return GraphEvent(id: deadline.id, date: date, mileage: mileage, title: deadline.title)
        }
        let projection = (0...24).compactMap { step -> GraphEvent? in
            let date = now.addingTimeInterval(window.upperBound.timeIntervalSince(now) * Double(step) / 24)
            guard let mileage = forecast.mileage(at: date) else { return nil }
            return GraphEvent(id: String(step), date: date, mileage: mileage, title: "Projected mileage")
        }
        let band = projection.compactMap { point -> ForecastBand? in
            guard let range = forecast.mileageRange(at: point.date) else { return nil }
            return ForecastBand(id: point.id, date: point.date, low: range.lowerBound, high: range.upperBound)
        }
        if let baseline = forecast.baseline {
            VStack(alignment: .leading, spacing: 4) {
                Text(forecast.mileage(at: now).map { "≈ \($0.formatted()) miles today" } ?? "\(baseline.mileage.formatted()) miles last recorded")
                    .font(.title3).bold().monospacedDigit()
                Text("Latest reading: \(baseline.mileage.formatted()) mi · \(baseline.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if let endMileage = forecast.mileage(at: window.upperBound) {
            Text("Projected by \(window.upperBound.formatted(date: .abbreviated, time: .omitted)): ≈ \(endMileage.formatted()) miles")
                .font(.subheadline).foregroundStyle(GarageTheme.accent)
        }
        Text(forecast.drivingComparison)
            .font(.subheadline).foregroundStyle(.secondary)
        Text(forecast.confidence.rawValue)
            .font(.caption.bold()).foregroundStyle(forecast.confidence == .learning ? .orange : GarageTheme.accent)
        if vehicle.drivingPurpose?.isEmpty != false || vehicle.estimatedMilesPerPeriod == nil {
            Text("Complete your required driving profile using Edit driving mileage.")
                .font(.caption).foregroundStyle(.orange)
        }
        Chart {
            ForEach(band) { point in
                AreaMark(x: .value("Date", point.date), yStart: .value("Low", point.low), yEnd: .value("High", point.high))
                    .foregroundStyle(GarageTheme.accent.opacity(0.12))
            }
            ForEach(projection) { point in
                LineMark(x: .value("Date", point.date), y: .value("Miles", point.mileage), series: .value("Series", "Predicted mileage"))
                    .foregroundStyle(GarageTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
            ForEach(history) { reading in
                PointMark(x: .value("Date", reading.date), y: .value("Miles", reading.mileage))
                    .foregroundStyle(reading.isService ? Color.mint : Color.white)
                    .symbol(reading.isService ? .diamond : .circle)
                    .symbolSize(65)
                    .accessibilityLabel(reading.title)
                    .accessibilityValue("\(reading.mileage) miles on \(reading.date.formatted(date: .abbreviated, time: .omitted))")
            }
            ForEach(upcoming) { event in
                PointMark(x: .value("Date", event.date), y: .value("Miles", event.mileage))
                    .foregroundStyle(.orange)
                    .symbol(.square)
                    .symbolSize(75)
                    .accessibilityLabel("Upcoming: \(event.title), projected mileage")
            }
            RuleMark(x: .value("Today", now))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .annotation(position: .top) { Text("Today").font(.caption2).foregroundStyle(.secondary) }
            if let selectedDate {
                RuleMark(x: .value("Selected date", selectedDate))
                    .foregroundStyle(GarageTheme.accent.opacity(0.5))
            }
        }
        .chartXScale(domain: window)
        .chartYScale(domain: mileageDomain(history: history, projection: projection, forecast: forecast))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        .chartXSelection(value: $selectedDate)
        .frame(height: 230)
        legend
        if let selectedDate {
            selection(date: selectedDate, forecast: forecast, history: history, upcoming: upcoming)
        } else {
            
        }
        if let rate = forecast.dailyMiles {
            Text("\(forecast.source) · ≈ \((rate * 7).formatted(.number.precision(.fractionLength(0)))) miles/week")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Text(mode == .profile
                 ? "Set your weekly or monthly driving mileage to enable this forecast."
                 : "Set driving mileage, or add readings at least seven days apart within the last six months, to forecast mileage.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if forecast.dailyMiles == 0 {
            Text("The selected driving rate is zero, so mileage stays flat. Edit driving mileage to enter how much you expect to drive.")
                .font(.caption).foregroundStyle(.secondary)
        }
        ForEach(forecast.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
        if !deadlines.isEmpty && upcoming.count < deadlines.count {
            Text("Some deadlines are outside this window or need a driving rate to appear. View all schedules in Reminders.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func mileageDomain(history: [MileageObservation], projection: [GraphEvent], forecast: MileageForecast) -> ClosedRange<Double> {
        let values = history.map { Double($0.mileage) } + projection.map { Double($0.mileage) } + [Double(forecast.baseline?.mileage ?? 0)]
        let low = values.min() ?? 0, high = values.max() ?? 1000
        let padding = max(250, (high - low) * 0.15)
        return max(0, low - padding)...(high + padding)
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { legendItems }
            VStack(alignment: .leading, spacing: 6) { legendItems }
        }
        .font(.caption2)
    }

    @ViewBuilder private var legendItems: some View {
        Label("Actual odometer", systemImage: "circle.fill").foregroundStyle(.white)
        Label("Service", systemImage: "diamond.fill").foregroundStyle(.mint)
        Label("Upcoming", systemImage: "square.fill").foregroundStyle(.orange)
        Label("Predicted mileage", systemImage: "line.diagonal").foregroundStyle(GarageTheme.accent)
    }

    @ViewBuilder private func selection(date: Date, forecast: MileageForecast, history: [MileageObservation], upcoming: [GraphEvent]) -> some View {
        let tolerance = window.upperBound.timeIntervalSince(window.lowerBound) / 40
        let reading = history.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        let event = upcoming.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        VStack(alignment: .leading, spacing: 4) {
            if let reading, abs(reading.date.timeIntervalSince(date)) <= tolerance {
                Text(reading.title).bold()
                Text("\(reading.date.formatted(date: .abbreviated, time: .omitted)) · \(reading.mileage.formatted()) miles recorded")
                if let expected = forecast.expectedMileage(at: reading.date) {
                    let difference = reading.mileage - expected
                    Text("Typical prediction: \(expected.formatted()) mi · \(difference >= 0 ? "+" : "")\(difference.formatted()) mi versus your routine")
                }
                if let cost = reading.cost { Text("Cost: $\(cost.formatted(.number.precision(.fractionLength(2))))") }
            } else if let event, abs(event.date.timeIntervalSince(date)) <= tolerance {
                Text(event.title).bold()
                Text("\(event.date.formatted(date: .abbreviated, time: .omitted)) · ≈ \(event.mileage.formatted()) miles projected")
                Text("Upcoming deadline; service has not been recorded as completed.")
            } else if date >= now, let mileage = forecast.mileage(at: date) {
                Text("\(date.formatted(date: .abbreviated, time: .omitted)) · ≈ \(mileage.formatted()) miles projected")
            } else {
                Text("No recorded reading near \(date.formatted(date: .abbreviated, time: .omitted)).")
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(GarageTheme.chrome, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct GraphEvent: Identifiable {
    let id: String
    let date: Date
    let mileage: Int
    let title: String
}

private struct ForecastBand: Identifiable {
    let id: String
    let date: Date
    let low: Int
    let high: Int
}
