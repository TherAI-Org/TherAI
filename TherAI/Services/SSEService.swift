import Foundation

final class SSEService {
    static let shared = SSEService()
    private init() {}

    func stream(request: URLRequest) -> AsyncStream<BackendService.StreamEvent> {
        return AsyncStream { continuation in
            let task = Task {
                do {
                    let config = URLSessionConfiguration.default
                    config.httpAdditionalHeaders = [
                        "Accept": "text/event-stream",
                        "Accept-Encoding": "identity",
                        "Cache-Control": "no-cache",
                        "Connection": "keep-alive"
                    ]
                    let session = URLSession(configuration: config)
                    print("[SSE] Starting stream: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
                    let (bytes, response) = try await session.bytes(for: request)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        print("[SSE] HTTP error: \(http.statusCode)")
                        continuation.yield(.error("HTTP \(http.statusCode)"))
                        continuation.finish()
                        return
                    }

                    var currentEvent: String? = nil
                    var dataLines: [String] = []

                    func flush() {
                        let dataString = dataLines.joined(separator: "\n")
                        switch currentEvent {
                        case "session":
                            if let json = dataString.data(using: .utf8),
                               let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                               let sidStr = obj["session_id"] as? String,
                               let sid = UUID(uuidString: sidStr) {
                                continuation.yield(.session(sid))
                            }
                        case "dialogue_session":
                            let trimmed = dataString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                            if let did = UUID(uuidString: trimmed) {
                                continuation.yield(.dialogueSession(did))
                            }
                        case "request":
                            let trimmed = dataString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                            if let rid = UUID(uuidString: trimmed) {
                                continuation.yield(.requestId(rid))
                            }
                        case "token":
                            let token: String
                            if let data = dataString.data(using: .utf8), let decoded = try? JSONDecoder().decode(String.self, from: data) {
                                token = decoded
                            } else {
                                token = dataString.replacingOccurrences(of: "\\n", with: "\n")
                                    .replacingOccurrences(of: "\\t", with: "\t")
                                    .replacingOccurrences(of: "\\\"", with: "\"")
                                    .replacingOccurrences(of: "\\\\", with: "\\")
                            }
                            print("[SSE] token chunk size=\(token.count)")
                            continuation.yield(.token(token))
                        case "done":
                            continuation.yield(.done)
                            continuation.finish()
                        case "error":
                            continuation.yield(.error(dataString.replacingOccurrences(of: "\"", with: "")))
                            continuation.finish()
                        default:
                            break
                        }
                        currentEvent = nil
                        dataLines.removeAll(keepingCapacity: false)
                    }

                    var tokenCount = 0
                    for try await rawLine in bytes.lines {
                        var line = String(rawLine)
                        if line.hasSuffix("\r") { line.removeLast() }
                        line = line.trimmingCharacters(in: .whitespaces)
                        // Debug the first few lines to ensure stream is flowing
                        if line.hasPrefix("event:") || line.hasPrefix("data:") { }
                        if line.isEmpty {
                            if currentEvent != nil || !dataLines.isEmpty { flush() }
                            continue
                        }
                        if line.hasPrefix("event:") {
                            currentEvent = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            if currentEvent == "token" {
                                // Emit tokens immediately rather than waiting for a trailing blank line
                                let token: String
                                if let data = value.data(using: .utf8), let decoded = try? JSONDecoder().decode(String.self, from: data) {
                                    token = decoded
                                } else {
                                    token = value.replacingOccurrences(of: "\\n", with: "\n")
                                        .replacingOccurrences(of: "\\t", with: "\t")
                                        .replacingOccurrences(of: "\\\"", with: "\"")
                                        .replacingOccurrences(of: "\\\\", with: "\\")
                                }
                                tokenCount += 1
                                if tokenCount % 8 == 0 { print("[SSE] tokens so far: \(tokenCount)") }
                                continuation.yield(.token(token))
                            } else {
                                dataLines.append(value)
                            }
                        } else {
                            // Ignore comments or other fields
                            continue
                        }
                    }

                    print("[SSE] Stream finished")
                    continuation.finish()
                } catch {
                    print("[SSE] Stream error: \(error.localizedDescription)")
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                print("[SSE] Terminated by client")
                task.cancel()
            }
        }
    }
}


