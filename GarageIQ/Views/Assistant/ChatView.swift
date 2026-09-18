import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var context
    @Query private var vehicles: [Vehicle]
    @Query(sort: \ChatConversation.createdAt, order: .reverse) private var conversations: [ChatConversation]
    @State private var deletionMessageID: UUID?
    @State private var receivedProposal: VehicleProposal?
    @State private var conversation: ChatConversation?
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var partial = ""
    @State private var pending = ""
    @State private var endpoint = "https://garageiq-api.onrender.com/chat"
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            DisclosureGroup("Conversations") {
                Menu("Saved conversations") {
                    ForEach(conversations) { chat in
                        Button(chat.title) { load(chat) }
                    }
                }.disabled(busy)
                Button("New conversation") { conversation = nil; messages = []; error = nil; partial = "" }.disabled(busy)
            }.padding()
            Text("Chats are saved on this device. Sending shares this conversation and all saved vehicles’ specs, mileage, driving profile, service history and schedules with your backend and OpenAI. Saved VIN, plate, shops, costs and notes are excluded.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(messages) { message in
                            bubble(message.content, user: message.role == "user")
                            if let proposal = message.proposal { proposalCard(proposal, message: message) }
                        }
                        if messages.isEmpty && !busy {
                            Text("Tell me about your garage. You can add your first vehicle here, update an odometer, or ask for a maintenance analysis of your whole garage.")
                                .foregroundStyle(.secondary)
                        }
                        if busy {
                            bubble(pending, user: true)
                            if partial.isEmpty { ProgressView("Replying…") } else { bubble(partial, user: false) }
                        }
                        if let error { Text(error).foregroundStyle(.red).font(.callout) }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding()
                }
                .onChange(of: partial) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            HStack {
                TextField("Tell me about your vehicles", text: $draft, axis: .vertical).lineLimit(1...5).textFieldStyle(.roundedBorder).disabled(busy)
                if busy { Button("Stop") { task?.cancel() } }
                else { Button("Send") { task = Task { await send() } }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.padding()
        }
        .navigationTitle("GarageIQ Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Analyze my garage") { draft = "Analyze the maintenance records for every vehicle in my garage. What needs attention, and what information is missing?" }
                Button("Review driving estimates") { draft = "Help me review my vehicles’ driving estimates. Ask about my routine and explain a plausible weekly mileage range before suggesting changes." }
            } label: { Label("Analyze", systemImage: "sparkles") }
            .disabled(busy || !draft.isEmpty)
        }
        .alert("Delete vehicle and its history?", isPresented: Binding(get: { deletionMessageID != nil }, set: { if !$0 { deletionMessageID = nil } })) {
            Button("Delete vehicle", role: .destructive) {
                if let id = deletionMessageID { resolve(id, save: true) }
                deletionMessageID = nil
            }
            Button("Cancel", role: .cancel) { deletionMessageID = nil }
        } message: {
            Text("This permanently removes the vehicle, its maintenance records and scheduled maintenance. Chat history is kept.")
        }
        .onDisappear { task?.cancel() }
    }

    private func proposalCard(_ proposal: VehicleProposal, message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(proposal.operation == "record" ? "Record completed service" : proposal.operation == "schedule" ? "Schedule maintenance" : (proposal.operation == "delete" ? "Delete vehicle" : (proposal.operation == "add" ? "Add vehicle" : "Update vehicle"))).font(.headline)
            if let target = message.proposalTarget {
                Text(target)
            } else if let vehicle = vehicles.first(where: { $0.id.uuidString == proposal.vehicleID }) {
                Text("\(vehicle.nickname.isEmpty ? vehicle.make : vehicle.nickname) · \(String(vehicle.year)) \(vehicle.make) \(vehicle.model)")
            }
            if proposal.operation == "delete" {
                Text("Permanently removes this vehicle, its maintenance records and scheduled maintenance.").foregroundStyle(.red)
            }
            if proposal.operation == "schedule" {
                Text("Saved in GarageIQ; phone notifications are not enabled. If both deadlines are set, whichever comes first applies.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(proposal.fields, id: \.0) { field in
                HStack { Text(field.0).foregroundStyle(.secondary); Spacer(); Text(field.1) }
            }
            if message.proposalStatus == "pending" {
                HStack {
                    if proposal.operation == "delete" {
                        Button("Delete vehicle…", role: .destructive) { deletionMessageID = message.id }.buttonStyle(.bordered)
                    } else {
                        Button(proposal.operation == "record" ? "Save service" : proposal.operation == "schedule" ? "Save schedule" : "Save vehicle") { resolve(message.id, save: true) }.buttonStyle(.borderedProminent)
                    }
                    Button("Dismiss") { resolve(message.id, save: false) }.buttonStyle(.bordered)
                }.disabled(busy)
            } else { Text(message.proposalStatus == "saved" ? (proposal.operation == "delete" ? "Vehicle deleted" : (proposal.operation == "record" ? "Service saved" : proposal.operation == "schedule" ? "Schedule saved" : "Saved to your garage")) : "Dismissed").font(.caption) }
        }.padding().background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func fingerprint(_ vehicle: Vehicle) -> String {
        // Detect edits made after a proposal was generated, including after relaunch.
        let values = [vehicle.nickname, String(vehicle.year), vehicle.make, vehicle.model, vehicle.trim,
                      String(vehicle.currentMileage), vehicle.vin ?? "", vehicle.licensePlate ?? "",
                      vehicle.drivingPurpose ?? "", vehicle.drivingPeriod ?? "", vehicle.estimatedMilesPerPeriod.map(String.init) ?? ""]
        return (try? JSONEncoder().encode(values).base64EncodedString()) ?? ""
    }

    @MainActor private func resolve(_ messageID: UUID, save: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }),
              messages[index].proposalStatus == "pending", let proposal = messages[index].proposal,
              let conversation else { return }
        do {
            if save {
                guard proposal.isValid else { throw changeError("This proposal is invalid. Ask the assistant to correct it.") }
                let vehicle: Vehicle
                if proposal.operation == "add" {
                    vehicle = Vehicle(year: proposal.year!, make: proposal.make!, model: proposal.model!, currentMileage: proposal.currentMileage!)
                    context.insert(vehicle)
                } else {
                    guard let existing = vehicles.first(where: { $0.id.uuidString == proposal.vehicleID }),
                          messages[index].vehicleBaseline == fingerprint(existing) else {
                        throw changeError("This vehicle changed or was removed. Ask for a fresh proposal before saving.")
                    }
                    vehicle = existing
                }
                if proposal.operation == "record" {
                    let record = MaintenanceRecord(vehicle: vehicle,
                        serviceType: proposal.serviceTitle!.trimmingCharacters(in: .whitespacesAndNewlines),
                        date: proposal.recordedDate!, mileage: proposal.serviceMileage!,
                        cost: proposal.serviceCost.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) },
                        shopName: (proposal.shopName ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: (proposal.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                    context.insert(record)
                } else if proposal.operation == "schedule" {
                    let reminder = MaintenanceReminder(vehicle: vehicle, title: proposal.serviceTitle!.trimmingCharacters(in: .whitespacesAndNewlines), dueDate: proposal.scheduledDate, dueMileage: proposal.dueMileage, notes: proposal.notes ?? "")
                    reminder.repeatMonths = proposal.repeatMonths
                    reminder.repeatMiles = proposal.repeatMiles
                    context.insert(reminder)
                } else if proposal.operation == "delete" {
                    context.delete(vehicle)
                } else {
                if let value = proposal.nickname { vehicle.nickname = value }
                if let value = proposal.year { vehicle.year = value }
                if let value = proposal.make { vehicle.make = value.trimmingCharacters(in: .whitespacesAndNewlines) }
                if let value = proposal.model { vehicle.model = value.trimmingCharacters(in: .whitespacesAndNewlines) }
                if let value = proposal.trim { vehicle.trim = value }
                if let value = proposal.vin { vehicle.vin = value }
                if let value = proposal.licensePlate { vehicle.licensePlate = value }
                if proposal.currentMileage != nil || proposal.estimatedMilesPerPeriod != nil || proposal.drivingPeriod != nil {
                    vehicle.estimateStartMileage = proposal.currentMileage ?? vehicle.estimatedMileage()
                    vehicle.estimateStartDate = .now
                }
                if let value = proposal.currentMileage { vehicle.currentMileage = value; vehicle.odometerConfirmedDate = .now }
                if let value = proposal.drivingPurpose { vehicle.drivingPurpose = value }
                if let value = proposal.drivingPeriod { vehicle.drivingPeriod = value }
                if let value = proposal.estimatedMilesPerPeriod { vehicle.estimatedMilesPerPeriod = value }
            }
            }
            var updated = messages
            updated[index].proposalStatus = save ? "saved" : "dismissed"
            conversation.transcript = try JSONEncoder().encode(updated)
            try context.save()
            messages = updated; error = nil
        } catch { context.rollback(); self.error = error.localizedDescription }
    }

    private func changeError(_ text: String) -> NSError {
        NSError(domain: "GarageIQ.Chat", code: 5, userInfo: [NSLocalizedDescriptionKey: text])
    }

    private func bubble(_ text: String, user: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(user ? "You" : "GarageIQ").font(.caption).foregroundStyle(.secondary)
            Text(text).textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: user ? .trailing : .leading)
        .background(user ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func load(_ chat: ChatConversation) {
        do { messages = try JSONDecoder().decode([ChatMessage].self, from: chat.transcript); conversation = chat; error = nil }
        catch { self.error = "This conversation could not be loaded." }
    }

    @MainActor private func send() async {
        guard let url = URL(string: endpoint) else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count <= 12000, messages.count < 40 else { error = "Limit messages to 12,000 characters. Start a new chat after 20 exchanges."; return }
        busy = true; receivedProposal = nil; pending = text; partial = ""; error = nil
        defer { busy = false }
        let baselines = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id.uuidString, fingerprint($0)) })
        let date = ISO8601DateFormatter()
        let garage: [[String: Any]] = vehicles.map { vehicle in [
            "id": vehicle.id.uuidString, "nickname": vehicle.nickname,
            "asOf": date.string(from: .now), "year": vehicle.year, "make": vehicle.make, "model": vehicle.model, "trim": vehicle.trim,
            "confirmedMileage": vehicle.currentMileage, "estimatedMileage": vehicle.estimatedMileage(), "estimated": vehicle.estimatedMilesPerPeriod != nil,
            "drivingUse": vehicle.drivingPurpose ?? "Unknown", "dailyMiles": vehicle.dailyDrivingMiles,
            "drivingPeriod": vehicle.drivingPeriod ?? "Unknown", "estimatedMilesPerPeriod": vehicle.estimatedMilesPerPeriod as Any? ?? NSNull(),
            "odometerConfirmedDate": vehicle.odometerConfirmedDate.map { date.string(from: $0) } ?? "Unknown",
            "services": vehicle.maintenanceRecords.map { ["service": $0.serviceType, "date": date.string(from: $0.date), "mileage": $0.mileage] as [String: Any] },
            "schedules": vehicle.maintenanceReminders.filter { !$0.completed }.map { ["title": $0.title, "dueDate": $0.dueDate.map { date.string(from: $0) } ?? "Unknown", "dueMileage": $0.dueMileage.map(String.init) ?? "Unknown"] }
        ]
        }
        let localDate = DateFormatter()
        localDate.locale = Locale(identifier: "en_US_POSIX")
        localDate.calendar = Calendar(identifier: .gregorian)
        localDate.dateFormat = "yyyy-MM-dd"
        let snapshot: [String: Any] = ["localDate": localDate.string(from: .now), "timeZone": TimeZone.current.identifier, "vehicles": garage, "asOf": date.string(from: .now)]
        let next = messages + [ChatMessage(role: "user", content: text)]
        do {
            let history = next.map { message -> [String: String] in
                var content = message.content
                if let proposal = message.proposal {
                    content += "\nProposed fields: " + proposal.fields.map { "\($0.0): \($0.1)" }.joined(separator: "; ")
                }
                if let status = message.proposalStatus { content += "\nProposal status: \(status)" }
                return ["role": message.role, "content": content]
            }
            let payload = try JSONSerialization.data(withJSONObject: ["supportsServiceRecords": true, "supportsScheduling": true, "supportsVehicleDeletion": true, "supportsVehicleChanges": true, "vehicleContext": snapshot, "messages": history])
            try await ChatService(endpoint: url).stream(payload: payload, onDelta: { partial += $0 }, onProposal: { receivedProposal = $0 })
            try Task.checkCancellation()
            if partial.isEmpty && receivedProposal != nil { partial = "Review this proposed change below. It has not been saved yet." }
            guard !partial.isEmpty else { throw NSError(domain: "Chat", code: 0, userInfo: [NSLocalizedDescriptionKey: "No reply received. Retry."]) }
            let completed = next + [ChatMessage(role: "assistant", content: partial, proposal: receivedProposal, proposalTarget: receivedProposal.flatMap { p in vehicles.first { $0.id.uuidString == p.vehicleID }.map { "\($0.nickname) \(String($0.year)) \($0.make) \($0.model)" } }, vehicleBaseline: receivedProposal.flatMap { p in p.vehicleID.flatMap { baselines[$0] } }, proposalStatus: receivedProposal == nil ? nil : "pending")]
            let saved = conversation ?? ChatConversation()
            let encoded = try JSONEncoder().encode(completed)
            if conversation == nil { context.insert(saved); saved.title = String(text.prefix(50)) }
            saved.transcript = encoded
            do { try context.save() } catch { context.rollback(); throw error }
            conversation = saved; messages = completed; draft = ""; partial = ""
        } catch {
            self.error = Task.isCancelled ? "Reply stopped. Your message is ready to resend." : error.localizedDescription
            partial = ""
        }
    }
}
