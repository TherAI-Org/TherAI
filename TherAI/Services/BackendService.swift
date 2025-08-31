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

    func sendChatMessage(_ message: String, accessToken: String) async throws -> String {
        let url = baseURL.appendingPathComponent("/chat/message")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let payload = ChatRequestBody(message: message)
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
        guard decoded.success else {
            throw NSError(domain: "Backend", code: -3, userInfo: [NSLocalizedDescriptionKey: "Request failed"])
        }
        return decoded.response
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
}

private struct ChatResponseBody: Codable {
    let response: String
    let success: Bool
}
