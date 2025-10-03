import Foundation

struct BackendService {

    static let shared = BackendService()

    let baseURL: URL
    private let urlSession: URLSession = .shared
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    private init() {
        guard let backendURLString = BackendService.getSecretsPlistValue(for: "BACKEND_BASE_URL") as? String,
              let url = URL(string: backendURLString) else {
            fatalError("Missing or invalid BACKEND_BASE_URL in Secrets.plist")
        }
        self.baseURL = url
        print("🌐 BackendService: Initialized with base URL: \(url)")
    }

    func sendChatMessage(_ message: String, sessionId: UUID?, chatHistory: [ChatHistoryMessage]?, accessToken: String, focusSnippet: String? = nil) async throws -> (response: String, sessionId: UUID) {
        let url = baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("sessions")
            .appendingPathComponent("message")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        // Do not advertise SSE for the non-streaming endpoint

        let payload = ChatRequestBody(message: message, session_id: sessionId, chat_history: chatHistory, focus_snippet: focusSnippet)
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

    // MARK: - Streaming (SSE)

    enum StreamEvent: Equatable {
        case session(UUID)
        case dialogueSession(UUID)
        case requestId(UUID)
        case token(String)
        case done
        case error(String)
    }

    func streamChatMessage(_ message: String, sessionId: UUID?, chatHistory: [ChatHistoryMessage]?, accessToken: String, focusSnippet: String? = nil) -> AsyncStream<StreamEvent> {
        var request = URLRequest(url: baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("sessions")
            .appendingPathComponent("message")
            .appendingPathComponent("stream"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let payload = ChatRequestBody(message: message, session_id: sessionId, chat_history: chatHistory, focus_snippet: focusSnippet)
        request.httpBody = try? jsonEncoder.encode(payload)

        return SSEService.shared.stream(request: request)
    }

    func streamDialogueRequest(_ requestBody: DialogueRequestBody, accessToken: String) -> AsyncStream<StreamEvent> {
        var request = URLRequest(url: baseURL
            .appendingPathComponent("dialogue")
            .appendingPathComponent("request")
            .appendingPathComponent("stream"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try? jsonEncoder.encode(requestBody)

        return SSEService.shared.stream(request: request)
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

    func createEmptySession(accessToken: String) async throws -> ChatSessionDTO {
        let url = baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("sessions")
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

        return try jsonDecoder.decode(ChatSessionDTO.self, from: data)
    }

    static func getSecretsPlistValue(for key: String) -> Any? {
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

// MARK: - Relationship Health API
extension BackendService {
    struct RelationshipHealthRequestBody: Codable { let last_run_at: String?; let force: Bool? }
    struct RelationshipHealthResponseBody: Codable { let summary: String; let last_run_at: String; let reason: String?; let has_any_messages: Bool }

    func fetchRelationshipHealth(accessToken: String, lastRunAt: Date?, force: Bool = false) async throws -> RelationshipHealthResponseBody {
        func makeRequest(at base: URL) throws -> URLRequest {
            let url = base
                .appendingPathComponent("relationship")
                .appendingPathComponent("health")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            let iso: String? = lastRunAt.map { d in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f.string(from: d)
            }
            let body = RelationshipHealthRequestBody(last_run_at: iso, force: force)
            req.httpBody = try jsonEncoder.encode(body)
            return req
        }

        // Primary attempt
        var request = try makeRequest(at: baseURL)
        var (data, response) = try await urlSession.data(for: request)
        var http = response as? HTTPURLResponse
        // Fallback: try /api prefix if 404 Not Found (some deployments mount under /api)
        if let h = http, h.statusCode == 404 {
            let apiBase = baseURL.appendingPathComponent("api")
            request = try makeRequest(at: apiBase)
            (data, response) = try await urlSession.data(for: request)
            http = response as? HTTPURLResponse
        }
        guard let finalHttp = http else {
            throw NSError(domain: "Backend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        guard (200..<300).contains(finalHttp.statusCode) else {
            let serverMessage = decodeSimpleDetail(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "Backend", code: finalHttp.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMessage])
        }
        return try jsonDecoder.decode(RelationshipHealthResponseBody.self, from: data)
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
    let focus_snippet: String?
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
    let last_message_at: String?
    let last_message_content: String?
}

// MARK: - Profile Avatar API
extension BackendService {
    func uploadAvatar(imageData: Data, contentType: String, accessToken: String) async throws -> (path: String, url: String?) {
        let url = baseURL
            .appendingPathComponent("profile")
            .appendingPathComponent("avatar")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var body = Data()
        let filename = "avatar"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Backend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = decodeSimpleDetail(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "Backend", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMessage])
        }
        struct UploadRes: Codable { let path: String?; let url: String? }
        let decoded = try jsonDecoder.decode(UploadRes.self, from: data)
        return (decoded.path ?? "", decoded.url)
    }

    struct PairedAvatars: Codable { struct Entry: Codable { let url: String?; let source: String } ; let me: Entry; let partner: Entry }
    func fetchPairedAvatars(accessToken: String) async throws -> PairedAvatars {
        let url = baseURL
            .appendingPathComponent("profile")
            .appendingPathComponent("avatars")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Backend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = decodeSimpleDetail(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "Backend", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMessage])
        }
        return try jsonDecoder.decode(PairedAvatars.self, from: data)
    }
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

    func fetchLinkStatus(accessToken: String) async throws -> (linked: Bool, relationshipId: UUID?, linkedAt: Date?) {
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

        struct StatusBody: Codable { let success: Bool; let linked: Bool; let relationship_id: UUID?; let linked_at: String? }
        let decoded = try jsonDecoder.decode(StatusBody.self, from: data)
        guard decoded.success else {
            throw NSError(domain: "Backend", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch link status"])
        }
        var linkedDate: Date? = nil
        if let iso = decoded.linked_at, !iso.isEmpty {
            // Parse ISO8601 or RFC3339 from backend
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            linkedDate = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        }
        return (decoded.linked, decoded.relationship_id, linkedDate)
    }

    // MARK: - Dialogue Methods
    func getDialogueMessages(accessToken: String, sourceSessionId: UUID) async throws -> DialogueMessagesResponse {
        let url = baseURL
            .appendingPathComponent("dialogue")
            .appendingPathComponent("messages")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "source_session_id", value: sourceSessionId.uuidString)]
        let finalURL = comps.url!
        var request = URLRequest(url: finalURL)
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

        return try jsonDecoder.decode(DialogueMessagesResponse.self, from: data)
    }

    func getPendingRequests(accessToken: String) async throws -> PendingRequestsResponse {
        let url = baseURL
            .appendingPathComponent("dialogue")
            .appendingPathComponent("pending-requests")
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

        return try jsonDecoder.decode(PendingRequestsResponse.self, from: data)
    }

    func createDialogueRequest(_ requestBody: DialogueRequestBody, accessToken: String) async throws -> DialogueRequestResponse {
        let url = baseURL
            .appendingPathComponent("dialogue")
            .appendingPathComponent("request")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        request.httpBody = try jsonEncoder.encode(requestBody)

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

        return try jsonDecoder.decode(DialogueRequestResponse.self, from: data)
    }

    func markRequestAsDelivered(requestId: UUID, accessToken: String) async throws {
        let url = baseURL
            .appendingPathComponent("dialogue")
            .appendingPathComponent("requests")
            .appendingPathComponent(requestId.uuidString)
            .appendingPathComponent("delivered")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
    }

    func markRequestAsAccepted(requestId: UUID, accessToken: String) async throws -> (partnerSessionId: UUID, dialogueSessionId: UUID) {
        let url = baseURL
            .appendingPathComponent("dialogue")
            .appendingPathComponent("requests")
            .appendingPathComponent(requestId.uuidString)
            .appendingPathComponent("accept")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        // Decode the response so caller can navigate to the correct dialogue
        struct AcceptDialogueResponse: Codable {
            let success: Bool
            let partner_session_id: UUID
            let dialogue_session_id: UUID
        }
        let decoded = try jsonDecoder.decode(AcceptDialogueResponse.self, from: data)
        return (decoded.partner_session_id, decoded.dialogue_session_id)
    }
}
