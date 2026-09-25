import Foundation

struct ChatStreamEvent: Decodable {
    var proposal: VehicleProposal?
    var delta: String?
    var done: Bool?
    var error: String?
    var requestID: String?
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
            if let error = event.error {
                let reference = event.requestID.map { " Reference: \($0)" } ?? ""
                throw failure(error + reference)
            }
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
