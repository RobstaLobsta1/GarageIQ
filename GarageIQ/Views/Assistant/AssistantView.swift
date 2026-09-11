import SwiftUI
import SwiftData

struct AssistantView: View {
    @Environment(\.modelContext) private var context
    @Query private var vehicles: [Vehicle]
    @State private var selectedID: UUID?
    @State private var endpoint = "https://garageiq-api.onrender.com/analyze"
    @State private var routine = ""
    @State private var result: VehicleAnalysis?
    @State private var analyzedVehicleID: UUID?
    @State private var error: String?
    @State private var busy = false
    @State private var applied = false

    var body: some View {
        Form {
            Section("Vehicle") {
                Picker("Analyze", selection: $selectedID) {
                    Text("Choose vehicle").tag(Optional<UUID>.none)
                    ForEach(vehicles) { vehicle in
                        Text("\(String(vehicle.year)) \(vehicle.make) \(vehicle.model)").tag(Optional(vehicle.id))
                    }
                }
                .disabled(busy)
            }
            Section("Driving routine") {
                TextField("Round-trip distance, days per week, work driving, errands and weekend trips", text: $routine, axis: .vertical)
                    .lineLimit(4...8)
                    .disabled(busy)
            }
            Section {
                Button(busy ? "Analyzing…" : "Analyze My Vehicle") { Task { await analyze() } }
                    .disabled(busy || selectedID == nil)
                if busy { ProgressView() }
            } footer: {
                Text("Sends vehicle specifications, confirmed/estimated mileage, driving profile, service dates/types/mileages, scheduled deadlines, and the routine you enter to your backend and OpenAI. VIN, license plate, shop, costs and saved notes are excluded. Don't enter identifying details in your routine.")
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            if let result {
                Section("Maintenance record assessment") {
                    Text(result.assessment).font(.headline)
                    Text(result.explanation)
                    Text("This is an assessment of recorded maintenance, not a mechanical diagnosis or assurance that the vehicle is safe to drive.").font(.caption).foregroundStyle(.secondary)
                }
                items("Recommended soon", result.recommendedSoon)
                items("Consider checking", result.considerations)
                items("History observations", result.observations)
                items("Missing information", result.missingInformation)
                items("Driving assumptions", result.drivingAssumptions)
                if let low = result.weeklyMilesLow, let high = result.weeklyMilesHigh, low >= 0, high >= low, high <= 100000 {
                    Section("Suggested driving estimate") {
                        Text("\(low)–\(high) miles per week")
                        Text("About \(Int(Double(low) * 30.4375 / 7))–\(Int(Double(high) * 30.4375 / 7)) miles per month")
                        Button(applied ? "Estimate applied" : "Use midpoint: \(low + (high - low) / 2) miles/week") { apply(low + (high - low) / 2) }
                            .disabled(applied || analyzedVehicleID != selectedID)
                        Text("You can adjust this estimate in Garage.").font(.caption)
                    }
                }
            }
        }
        .navigationTitle("GarageIQ Assistant")
        .onAppear { if selectedID == nil { selectedID = vehicles.first?.id } }
        .onChange(of: selectedID) { _, _ in result = nil; applied = false; error = nil }
    }

    @ViewBuilder private func items(_ title: String, _ values: [String]) -> some View {
        if !values.isEmpty { Section(title) { ForEach(Array(values.enumerated()), id: \.offset) { Text($0.element) } } }
    }

    @MainActor private func analyze() async {
        guard let vehicle = vehicles.first(where: { $0.id == selectedID }), let url = URL(string: endpoint) else { error = "Choose a vehicle and valid backend URL."; return }
        guard routine.count <= 4000, vehicle.maintenanceRecords.count <= 200 else { error = "Limit the routine to 4,000 characters and history to 200 records for this version."; return }
        busy = true; result = nil; error = nil; applied = false
        defer { busy = false }
        let now = Date.now
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "asOf": formatter.string(from: now), "routine": routine,
            "vehicle": ["year": vehicle.year, "make": vehicle.make, "model": vehicle.model, "trim": vehicle.trim,
                        "confirmedMileage": vehicle.currentMileage, "estimatedMileage": vehicle.estimatedMileage(at: now),
                        "estimatesEnabled": vehicle.estimatedMilesPerPeriod != nil,
                        "use": vehicle.drivingPurpose ?? "Unknown", "weeklyMiles": vehicle.dailyDrivingMiles * 7] as [String: Any],
            "records": vehicle.maintenanceRecords.map { ["serviceType": $0.serviceType, "date": formatter.string(from: $0.date), "mileage": $0.mileage] as [String: Any] },
            "schedules": vehicle.maintenanceReminders.filter { !$0.completed }.map { ["title": $0.title, "dueDate": $0.dueDate.map { formatter.string(from: $0) } ?? "Unknown", "dueMileage": $0.dueMileage.map(String.init) ?? "Unknown"] }
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            result = try await BackendAIService(endpoint: url).analyze(payload: data)
            analyzedVehicleID = vehicle.id
        } catch { self.error = error.localizedDescription }
    }

    private func apply(_ miles: Int) {
        guard let vehicle = vehicles.first(where: { $0.id == analyzedVehicleID }), analyzedVehicleID == selectedID else { return }
        var form = VehicleFormData(vehicle: vehicle)
        form.estimateEnabled = true; form.drivingPeriod = "Weekly"; form.drivingMiles = String(miles)
        guard form.validationErrors.isEmpty else { error = form.validationErrors.joined(separator: " "); return }
        form.apply(to: vehicle)
        do { try context.save(); applied = true } catch { context.rollback(); self.error = error.localizedDescription }
    }
}
