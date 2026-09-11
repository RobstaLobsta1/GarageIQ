import Foundation
import Security

struct VehicleAnalysis: Decodable {
    let assessment: String
    let explanation: String
    let recommendedSoon: [String]
    let considerations: [String]
    let observations: [String]
    let missingInformation: [String]
    let drivingAssumptions: [String]
    let weeklyMilesLow: Int?
    let weeklyMilesHigh: Int?
}

protocol AIService {
    func analyze(payload: Data) async throws -> VehicleAnalysis
}

struct BackendAIService: AIService {
    let endpoint: URL

    func analyze(payload: Data) async throws -> VehicleAnalysis {
        var allowed = endpoint.scheme == "https"
        #if DEBUG
        allowed = allowed || (endpoint.scheme == "http" && endpoint.host == "localhost")
        #endif
        guard allowed, endpoint.host != nil, endpoint.user == nil, endpoint.password == nil else {
            throw NSError(domain: "GarageIQ", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter your backend's HTTPS /analyze URL."])
        }
        let accessToken = try await AnonymousSession.shared.token()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 75
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = payload
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401 { await AnonymousSession.shared.invalidate() }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(BackendError.self, from: data))?.error ?? "Unable to reach the assistant. Please try again shortly."
            throw NSError(domain: "GarageIQ", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder().decode(VehicleAnalysis.self, from: data)
    }

    private struct BackendError: Decodable { let error: String }
}

// One anonymous session shared by chat and analysis, persisted only in Keychain.
actor AnonymousSession {
    static let shared = AnonymousSession()
    private struct Session: Codable { let token: String; let expiresAt: Double }
    private var pending: Task<String, Error>?
    private let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "GarageIQ.Render.Session", kSecAttrAccount as String: "anonymous"]

    func invalidate() { SecItemDelete(query as CFDictionary) }

    func token() async throws -> String {
        if let pending { return try await pending.value }
        var read = query
        read[kSecReturnData as String] = true
        var item: CFTypeRef?
        if SecItemCopyMatching(read as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data, let session = try? JSONDecoder().decode(Session.self, from: data),
           session.expiresAt > Date().timeIntervalSince1970 * 1000 + 60000 { return session.token }
        let task = Task<String, Error> {
            var request = URLRequest(url: URL(string: "https://garageiq-api.onrender.com/session")!)
            request.httpMethod = "POST"
            request.timeoutInterval = 90
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(domain: "GarageIQ", code: 3, userInfo: [NSLocalizedDescriptionKey: "Chat could not connect. Please try again shortly."])
            }
            let session = try JSONDecoder().decode(Session.self, from: data)
            var save = query
            save[kSecValueData as String] = data
            save[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemDelete(query as CFDictionary)
            guard SecItemAdd(save as CFDictionary, nil) == errSecSuccess else {
                throw NSError(domain: "GarageIQ", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to save your chat session securely. Please retry."])
            }
            return session.token
        }
        pending = task
        defer { pending = nil }
        return try await task.value
    }
}
