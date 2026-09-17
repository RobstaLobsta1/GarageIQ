import Foundation

struct ChatStreamEvent: Decodable {
    var proposal: VehicleProposal?
    var delta: String?
    var done: Bool?
    var error: String?
}

struct ChatService {
    let endpoint: URL

    @MainActor func stream(payload: Data, onDelta: (String) -> Void, onProposal: (VehicleProposal) -> Void) async throws {
        var allowed = endpoint.scheme == "https"
        #if DEBUG
        allowed = allowed || (endpoint.scheme == "http" && endpoint.host == "localhost")
        #endif
        guard allowed, endpoint.host != nil, endpoint.user == nil, endpoint.password == nil else { throw failure("Use HTTPS, or localhost HTTP in a Debug build.") }
        guard payload.count <= 64000 else { throw failure("Conversation is too large. Start a new chat.") }
        let token = try await AnonymousSession.shared.token()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401 { await AnonymousSession.shared.invalidate() }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw failure("Unable to start chat. Please try again shortly.") }
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard !line.isEmpty else { continue }
            let event = try JSONDecoder().decode(ChatStreamEvent.self, from: Data(line.utf8))
            if let error = event.error { throw failure(error) }
            if let delta = event.delta { onDelta(delta) }
            if let proposal = event.proposal { onProposal(proposal) }
            if event.done == true { return }
        }
        throw failure("The reply ended early. Retry your message.")
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "GarageIQ.Chat", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

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
        for (label, value) in [("Nickname", nickname), ("Year", year.map(String.init)), ("Make", make), ("Model", model), ("Trim", trim), ("Odometer", currentMileage.map { "\($0) miles" }), ("VIN", vin), ("License plate", licensePlate), ("Driving use", drivingPurpose), ("Driving period", drivingPeriod), ("Estimated distance", estimatedMilesPerPeriod.map { "\($0) miles" })] {
            if let value { rows.append((label, value.isEmpty ? "(empty)" : value)) }
        }
        return rows
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
            return dueDate == nil && dueMileage == nil && repeatMonths == nil && repeatMiles == nil && nickname == nil && year == nil && make == nil && model == nil && trim == nil && currentMileage == nil && vin == nil && licensePlate == nil && drivingPurpose == nil && drivingPeriod == nil && estimatedMilesPerPeriod == nil
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
            return nickname == nil && year == nil && make == nil && model == nil && trim == nil && currentMileage == nil && vin == nil && licensePlate == nil && drivingPurpose == nil && drivingPeriod == nil && estimatedMilesPerPeriod == nil
        }
        guard serviceTitle == nil && dueDate == nil && notes == nil && dueMileage == nil && repeatMonths == nil && repeatMiles == nil else { return false }
        if operation == "delete" { return fields.isEmpty && vehicleID.flatMap(UUID.init(uuidString:)) != nil }
        guard ["add", "update"].contains(operation), !fields.isEmpty else { return false }
        if let year, !(1900...(Calendar.current.component(.year, from: .now) + 1)).contains(year) { return false }
        for value in [currentMileage, estimatedMilesPerPeriod] { if let value, !(0...10000000).contains(value) { return false } }
        for value in [make, model] { if let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false } }
        for value in [nickname, make, model, trim, vin, licensePlate, drivingPurpose, drivingPeriod] { if let value, value.count > 500 { return false } }
        if let drivingPeriod, !["Weekly", "Monthly"].contains(drivingPeriod) { return false }
        if estimatedMilesPerPeriod != nil && drivingPeriod == nil { return false }
        if operation == "add" { return vehicleID == nil && year != nil && make != nil && model != nil && currentMileage != nil }
        return vehicleID.flatMap(UUID.init(uuidString:)) != nil
    }
}
