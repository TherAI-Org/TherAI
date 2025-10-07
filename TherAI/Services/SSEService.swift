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
                    var sawToolStart = false
                    var sawPartnerMessage = false
                    var rawLineCount = 0
                    let rawLineLogLimit = 80

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
                        case "partner_message":
                            let text: String
                            if let data = dataString.data(using: .utf8), let decoded = try? JSONDecoder().decode(String.self, from: data) {
                                text = decoded
                            } else {
                                text = dataString
                            }
                            print("[SSE] partner_message received len=\(text.count)")
                            continuation.yield(.partnerMessage(text))
                            sawPartnerMessage = true
                        case "tool_start":
                            if let data = dataString.data(using: .utf8),
                               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let name = obj["name"] as? String {
                                print("[SSE] tool_start received name=\(name)")
                                continuation.yield(.toolStart(name))
                            } else {
                                print("[SSE] tool_start received (no name)")
                                continuation.yield(.toolStart(""))
                            }
                            sawToolStart = true
                        case "tool_args":
                            if !sawToolStart {
                                print("[SSE] tool_args before tool_start; synthesizing toolStart for UI")
                                continuation.yield(.toolStart(""))
                                sawToolStart = true
                            }
                            continuation.yield(.toolArgs(dataString))
                        case "tool_done":
                            continuation.yield(.toolDone)
                        case "done":
                            print("[SSE] done received; sawToolStart=\(sawToolStart) sawPartnerMessage=\(sawPartnerMessage)")
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
                        if rawLineCount < rawLineLogLimit {
                            let preview = line.count > 200 ? String(line.prefix(200)) + "…" : line
                            print("[SSE][raw] \(rawLineCount): \(preview)")
                            rawLineCount += 1
                        }
                        if line.hasSuffix("\r") { line.removeLast() }
                        line = line.trimmingCharacters(in: .whitespaces)
                        // Debug the first few lines to ensure stream is flowing
                        if line.hasPrefix("event:") || line.hasPrefix("data:") { }
                        if line.isEmpty {
                            if currentEvent != nil || !dataLines.isEmpty { flush() }
                            continue
                        }
                        if line.hasPrefix("event:") {
                            if currentEvent != nil || !dataLines.isEmpty { flush() }
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

                    // Flush any pending event at EOF (prevents losing the final event if stream closes without a trailing blank line)
                    if currentEvent != nil || !dataLines.isEmpty { flush() }

                    print("[SSE] Stream finished (EOF) sawToolStart=\(sawToolStart) sawPartnerMessage=\(sawPartnerMessage)")
                    continuation.finish()
                } catch {
                    print("[SSE] Stream error: \(error.localizedDescription)")
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                print("[SSE] Terminated by client (onTermination)")
                task.cancel()
            }
        }
    }
}


