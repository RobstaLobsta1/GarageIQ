import Foundation
import SwiftData

struct ChatMessage: Codable, Identifiable {
    var id = UUID()
    let role: String
    let content: String
    var proposal: VehicleProposal? = nil
    var proposalTarget: String? = nil
    var vehicleBaseline: String? = nil
    var proposalStatus: String? = nil
}

@Model
final class ChatConversation {
    @Attribute(.unique) var id: UUID
    var vehicleID: UUID
    var title: String
    var createdAt: Date
    var transcript: Data

    init(vehicleID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!) {
        id = UUID()
        self.vehicleID = vehicleID
        title = "New conversation"
        createdAt = .now
        transcript = Data("[]".utf8)
    }
}
