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

    func sendChatMessage(_ message: String, sessionId: UUID?, chatHistory: [ChatHistoryMessage]?, accessToken: String) async throws -> (response: String, sessionId: UUID) {
        let url = baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("sessions")
            .appendingPathComponent("message")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let payload = ChatRequestBody(message: message, session_id: sessionId, chat_history: chatHistory)
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

struct ChatHistoryMessage: Codable {
    let role: String
    let content: String
}

private struct ChatRequestBody: Codable {
    let message: String
    let session_id: UUID?
    let chat_history: [ChatHistoryMessage]?
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

// Link Invites
private struct CreateLinkInviteResponseBody: Codable {
    let invite_token: String
    let share_url: String
}

private struct AcceptLinkInviteRequestBody: Codable {
    let invite_token: String
}

private struct AcceptLinkInviteResponseBody: Codable {
    let success: Bool
    let relationship_id: UUID?
}

extension BackendService {
    func createLinkInvite(accessToken: String) async throws -> URL {
        let url = baseURL
            .appendingPathComponent("link")
            .appendingPathComponent("send-invite")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

        let decoded = try jsonDecoder.decode(CreateLinkInviteResponseBody.self, from: data)
        guard let shareURL = URL(string: decoded.share_url) else {
            throw NSError(domain: "Backend", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid share URL from server"])
        }
        return shareURL
    }

    func acceptLinkInvite(inviteToken: String, accessToken: String) async throws {
        let url = baseURL
            .appendingPathComponent("link")
            .appendingPathComponent("accept-invite")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let payload = AcceptLinkInviteRequestBody(invite_token: inviteToken)
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

        let decoded = try jsonDecoder.decode(AcceptLinkInviteResponseBody.self, from: data)
        guard decoded.success else {
            throw NSError(domain: "Backend", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to accept link invite"])
        }
    }

    func unlink(accessToken: String) async throws -> Bool {
        let url = baseURL
            .appendingPathComponent("link")
            .appendingPathComponent("unlink-pair")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

        struct UnlinkResponseBody: Codable { let success: Bool; let unlinked: Bool }
        let decoded = try jsonDecoder.decode(UnlinkResponseBody.self, from: data)
        guard decoded.success else {
            throw NSError(domain: "Backend", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to unlink"])
        }
        return decoded.unlinked
    }

    func fetchLinkStatus(accessToken: String) async throws -> (linked: Bool, relationshipId: UUID?) {
        let url = baseURL
            .appendingPathComponent("link")
            .appendingPathComponent("status")
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

        struct StatusBody: Codable { let success: Bool; let linked: Bool; let relationship_id: UUID? }
        let decoded = try jsonDecoder.decode(StatusBody.self, from: data)
        guard decoded.success else {
            throw NSError(domain: "Backend", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch link status"])
        }
        return (decoded.linked, decoded.relationship_id)
    }
}
