import Foundation

struct BackendService {

    static let shared = BackendService()

    private let baseURL: URL
    private let urlSession: URLSession = .shared
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    private init() {
        guard let backendURLString = BackendService.getSecretsPlistValue(for: "BACKEND_BASE_URL") as? String,
              let url = URL(string: backendURLString) else {
            fatalError("Missing or invalid BACKEND_BASE_URL in Secrets.plist")
        }
        self.baseURL = url
    }

    func sendChatMessage(_ message: String, sessionId: UUID?, accessToken: String) async throws -> (response: String, sessionId: UUID) {
        let url = baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("sessions")
            .appendingPathComponent("message")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let payload = ChatRequestBody(message: message, session_id: sessionId)
        request.httpBody = try jsonEncoder.encode(payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Backend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = decodeSimpleDetail(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "Backend", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMessage])
        }

        let decoded = try jsonDecoder.decode(ChatResponseBody.self, from: data)
        guard decoded.success, let sid = decoded.session_id else {
            throw NSError(domain: "Backend", code: -3, userInfo: [NSLocalizedDescriptionKey: "Request failed"])
        }
        return (decoded.response, sid)
    }

    func fetchMessages(sessionId: UUID, accessToken: String) async throws -> [ChatMessageDTO] {
        let url = baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId.uuidString)
            .appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Backend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = decodeSimpleDetail(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "Backend", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMessage])
        }

        let decoded = try jsonDecoder.decode(MessagesResponseBody.self, from: data)
        return decoded.messages
    }

    func fetchSessions(accessToken: String) async throws -> [ChatSessionDTO] {
        let url = baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Backend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = decodeSimpleDetail(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "Backend", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMessage])
        }

        let decoded = try jsonDecoder.decode(SessionsResponseBody.self, from: data)
        return decoded.sessions
    }

    private static func getSecretsPlistValue(for key: String) -> Any? {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let value = plist[key] {
            return value
        }
        return nil
    }

    private func decodeSimpleDetail(from data: Data) -> String? {
        struct SimpleDetail: Decodable { let detail: String? }
        return (try? jsonDecoder.decode(SimpleDetail.self, from: data))?.detail
    }
}

private struct ChatRequestBody: Codable {
    let message: String
    let session_id: UUID?
}

private struct ChatResponseBody: Codable {
    let response: String
    let success: Bool
    let session_id: UUID?
}

struct ChatMessageDTO: Codable {
    let id: UUID
    let user_id: UUID
    let session_id: UUID
    let role: String
    let content: String
}

private struct MessagesResponseBody: Codable {
    let messages: [ChatMessageDTO]
}

struct ChatSessionDTO: Codable {
    let id: UUID
    let title: String?
}

private struct SessionsResponseBody: Codable {
    let sessions: [ChatSessionDTO]
}
