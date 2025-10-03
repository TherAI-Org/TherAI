import Foundation
import SwiftUI

@MainActor
class DialogueViewModel: ObservableObject {
    @Published var messages: [DialogueMessage] = []
    @Published var pendingRequests: [DialogueRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isStreaming = false

    private let backendService = BackendService.shared
    private var acceptedRequestIds: Set<UUID> = []
    
    // Track the current session ID to know when we're switching between different sessions
    private var currentSessionId: UUID?
    
    // Cache dialogue messages per session to avoid unnecessary API calls
    private var messagesCache: [UUID: [DialogueMessage]] = [:]
    private var cacheTimestamps: [UUID: Date] = [:]
    private let cacheValiditySeconds: TimeInterval = 300 // 5 minutes

    // Sanitizes streamed dialogue text that may arrive as a quoted JSON string
    // - Removes leading/trailing quotes
    // - Optionally decodes common JSON escape sequences on finalization
    private func sanitizeStreamContent(_ text: String, isFinal: Bool) -> String {
        var cleaned = text
        if cleaned.first == "\"" { cleaned.removeFirst() }
        if isFinal, cleaned.last == "\"" { cleaned.removeLast() }

        // On final, attempt to fully JSON-decode in case of escape sequences
        if isFinal {
            // Try as-is first (already quoted), then wrap if needed
            let attempts: [String] = ["\"" + cleaned + "\"", cleaned]
            for candidate in attempts {
                if let data = candidate.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(String.self, from: data) {
                    return decoded
                }
            }
        }

        // During streaming, do a light unescape for readability
        cleaned = cleaned
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\r", with: "\r")
        return cleaned
    }

    // Callback for refreshing pending requests in sidebar
    var onRefreshPendingRequests: (() -> Void)?
    // Callback to request the UI to switch into Dialogue mode
    var onSwitchToDialogue: (() -> Void)?

    struct DialogueMessage: Identifiable, Codable {
        let id: UUID
        let dialogueSessionId: UUID
        let requestId: UUID?
        let content: String
        let messageType: String
        let senderUserId: UUID
        let createdAt: String

        var isFromPartner: Bool {
            // This would need to be compared with current user ID
            // For now, we'll assume it's from partner if messageType is "request"
            return messageType == "request"
        }

        enum CodingKeys: String, CodingKey {
            case id
            case dialogueSessionId = "dialogue_session_id"
            case requestId = "request_id"
            case content
            case messageType = "message_type"
            case senderUserId = "sender_user_id"
            case createdAt = "created_at"
        }
    }

    /// Returns the dialogue session id mapped from a personal source session, if any
    func getDialogueSessionId(for sourceSessionId: UUID) async -> UUID? {
        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else { return nil }
            let response = try await backendService.getDialogueMessages(accessToken: accessToken, sourceSessionId: sourceSessionId)
            return response.dialogueSessionId
        } catch {
            return nil
        }
    }

    struct DialogueRequest: Identifiable, Codable {
        let id: UUID
        let senderUserId: UUID
        let senderSessionId: UUID
        let requestContent: String
        let createdAt: String
        let status: String

        enum CodingKeys: String, CodingKey {
            case id
            case senderUserId = "sender_user_id"
            case senderSessionId = "sender_session_id"
            case requestContent = "request_content"
            case createdAt = "created_at"
            case status
        }
    }

    func loadDialogueMessages(sourceSessionId: UUID? = nil, forceRefresh: Bool = false) async {
        // Do not overwrite local streaming state while streaming
        if isStreaming { return }
        
        // Require a source session id to scope the dialogue
        guard let sid = sourceSessionId else { 
            self.errorMessage = "Missing source session id"
            return 
        }
        
        // Check if we're switching to a different session
        let isSessionChange = currentSessionId != sid
        
        // Handle session switching
        if isSessionChange {
            currentSessionId = sid
            // Don't clear messages immediately - let the UI handle the transition
        } else if sourceSessionId != nil {
            currentSessionId = sourceSessionId
        }
        
        // Check cache first for instant loading
        if !forceRefresh, !isSessionChange, let cachedMessages = messagesCache[sid], let timestamp = cacheTimestamps[sid] {
            let age = Date().timeIntervalSince(timestamp)
            if age < cacheValiditySeconds {
                // Use cached messages for instant display
                self.messages = cachedMessages
                isLoading = false
                // Still refresh in background silently if cache is getting old
                if age > cacheValiditySeconds * 0.7 { // 70% of cache validity
                    Task {
                        await loadDialogueMessages(sourceSessionId: sid, forceRefresh: true)
                    }
                }
                return
            }
        }
        
        // Show loading only if we don't have any messages to display and it's not a session change
        if self.messages.isEmpty && !isSessionChange {
            isLoading = true
        }
        errorMessage = nil

        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }

            let response = try await backendService.getDialogueMessages(accessToken: accessToken, sourceSessionId: sid)
            
            // Update cache
            messagesCache[sid] = response.messages
            cacheTimestamps[sid] = Date()
            
            // Update messages with smooth transition
            await MainActor.run {
                self.messages = response.messages
                self.errorMessage = nil
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load dialogue messages: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }


    func loadPendingRequests() async {
        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }

            let response = try await backendService.getPendingRequests(accessToken: accessToken)
            self.pendingRequests = response.requests
        } catch {
            self.errorMessage = "Failed to load pending requests: \(error.localizedDescription)"
        }
    }

    func sendToPartner(sessionId: UUID, customMessage: String? = nil) async {
        isLoading = true
        errorMessage = nil
        isStreaming = true

        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }

            let request = DialogueRequestBody(
                message: customMessage ?? "",
                sessionId: sessionId
            )

            var accumulated = ""
            var currentDialogueSessionId: UUID? = nil
            var placeholderIndex: Int? = nil

            let stream = backendService.streamDialogueRequest(request, accessToken: accessToken)
            print("[Dialogue] Starting stream to /dialogue/request/stream sessionId=\(sessionId)")

            // Fallback: if no SSE activity after 6s, call non-stream endpoint
            let fallbackTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard let self = self, !Task.isCancelled else { return }
                do {
                    print("[Dialogue] Fallback triggered — calling non-stream create")
                    let result = try await self.backendService.createDialogueRequest(request, accessToken: accessToken)
                    await MainActor.run {
                        self.isStreaming = false
                    }
                    // Reconcile with server state without switching modes
                    await loadDialogueMessages(sourceSessionId: sessionId)
                    print("[Dialogue] Fallback success — requestId=\(result.requestId) dialogueId=\(result.dialogueSessionId)")
                    return
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Dialogue fallback failed: \(error.localizedDescription)"
                        self.isLoading = false
                        self.isStreaming = false
                    }
                }
            }
            var receivedAnyEvent = false
            for await event in stream {
                receivedAnyEvent = true
                switch event {
                case .dialogueSession(let did):
                    fallbackTask.cancel()
                    print("[Dialogue] Received dialogueSession id=\(did)")
                    currentDialogueSessionId = did
                    // No auto-switch; UI switches only on pending request acceptance.
                case .token(let token):
                    fallbackTask.cancel()
                    if accumulated.isEmpty { print("[Dialogue] First token received length=\(token.count)") }
                    accumulated += token
                    // No auto-switch; UI switches only on pending request acceptance.
                    // Create placeholder on first token
                    if placeholderIndex == nil {
                        let userId = AuthService.shared.currentUser?.id ?? UUID()
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let createdAt = formatter.string(from: Date())

                        let placeholder = DialogueMessage(
                            id: UUID(),
                            dialogueSessionId: currentDialogueSessionId ?? sessionId,
                            requestId: nil,
                            content: "",
                            messageType: "request",
                            senderUserId: userId,
                            createdAt: createdAt
                        )
                        self.messages.append(placeholder)
                        placeholderIndex = self.messages.count - 1
                    }
                    if let idx = placeholderIndex, idx < self.messages.count {
                        let existing = self.messages[idx]
                        let display = sanitizeStreamContent(accumulated, isFinal: false)
                        let updated = DialogueMessage(
                            id: existing.id,
                            dialogueSessionId: existing.dialogueSessionId,
                            requestId: existing.requestId,
                            content: display,
                            messageType: existing.messageType,
                            senderUserId: existing.senderUserId,
                            createdAt: existing.createdAt
                        )
                        var newMessages = self.messages
                        newMessages[idx] = updated
                        self.messages = newMessages
                    }
                case .requestId(let rid):
                    fallbackTask.cancel()
                    print("[Dialogue] Persisted requestId=\(rid)")
                    if let idx = placeholderIndex, idx < self.messages.count {
                        let existing = self.messages[idx]
                        let updated = DialogueMessage(
                            id: existing.id,
                            dialogueSessionId: existing.dialogueSessionId,
                            requestId: rid,
                            content: existing.content,
                            messageType: existing.messageType,
                            senderUserId: existing.senderUserId,
                            createdAt: existing.createdAt
                        )
                        var newMessages = self.messages
                        newMessages[idx] = updated
                        self.messages = newMessages
                    }
                case .done:
                    fallbackTask.cancel()
                    print("[Dialogue] Stream done — success")
                    // Final sanitize of placeholder content before reconciling
                    if let idx = placeholderIndex, idx < self.messages.count {
                        let existing = self.messages[idx]
                        let display = sanitizeStreamContent(accumulated, isFinal: true)
                        let updated = DialogueMessage(
                            id: existing.id,
                            dialogueSessionId: existing.dialogueSessionId,
                            requestId: existing.requestId,
                            content: display,
                            messageType: existing.messageType,
                            senderUserId: existing.senderUserId,
                            createdAt: existing.createdAt
                        )
                        var newMessages = self.messages
                        newMessages[idx] = updated
                        self.messages = newMessages
                    }
                    isLoading = false
                    // Switch to dialogue tab after successful message send
                    onSwitchToDialogue?()
                case .error(let msg):
                    fallbackTask.cancel()
                    print("[Dialogue] Stream error: \(msg)")
                    errorMessage = msg
                    isLoading = false
                default:
                    break
                }
            }

            if !receivedAnyEvent {
                print("[Dialogue] No SSE events received — server may have returned non-200 or no body")
            }
                    // Stop streaming first, then reconcile with server state
            isStreaming = false
            // Clear cache to ensure we get the latest messages from server
            clearCache(for: sessionId)
            await loadDialogueMessages(sourceSessionId: sessionId, forceRefresh: true)

        } catch {
            self.errorMessage = "Failed to send to partner: \(error.localizedDescription)"
            isStreaming = false
        }

        isLoading = false
    }

    func markRequestAsDelivered(requestId: UUID) async {
        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }

            try await backendService.markRequestAsDelivered(requestId: requestId, accessToken: accessToken)
        } catch {
            self.errorMessage = "Failed to mark request as delivered: \(error.localizedDescription)"
        }
    }

    func markRequestAsAccepted(requestId: UUID) async {
        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }

            _ = try await backendService.markRequestAsAccepted(requestId: requestId, accessToken: accessToken)
            acceptedRequestIds.insert(requestId)
            // Notify others that relationship totals likely changed
            NotificationCenter.default.post(name: .relationshipTotalsChanged, object: nil)
        } catch {
            self.errorMessage = "Failed to mark request as accepted: \(error.localizedDescription)"
        }
    }
    
    /// Clear dialogue messages for the current session
    /// This ensures a clean state when switching between chat sessions
    func clearMessages() {
        self.messages = []
        self.errorMessage = nil
        self.currentSessionId = nil
        self.isLoading = false
    }
    
    /// Force clear messages and reset session tracking
    /// Use this when explicitly switching to a different chat session
    func clearMessagesForNewSession(_ newSessionId: UUID) {
        self.messages = []
        self.errorMessage = nil
        self.currentSessionId = newSessionId
    }
    
    /// Clear cache for a specific session (useful when messages are updated)
    func clearCache(for sessionId: UUID) {
        messagesCache.removeValue(forKey: sessionId)
        cacheTimestamps.removeValue(forKey: sessionId)
    }
    
    /// Load messages for a new session with smooth transition
    /// This provides instant loading from cache when possible
    func loadMessagesForNewSession(_ newSessionId: UUID) async {
        currentSessionId = newSessionId
        
        // Try to load from cache first for instant display
        if let cachedMessages = messagesCache[newSessionId], let timestamp = cacheTimestamps[newSessionId] {
            let age = Date().timeIntervalSince(timestamp)
            if age < cacheValiditySeconds {
                // Show cached messages immediately
                self.messages = cachedMessages
                isLoading = false
                // Still refresh in background to ensure we have latest data
                Task {
                    await loadDialogueMessages(sourceSessionId: newSessionId, forceRefresh: true)
                }
                return
            }
        }
        
        // No cache available, load fresh
        await loadDialogueMessages(sourceSessionId: newSessionId, forceRefresh: true)
    }
}

// MARK: - Backend Models
struct DialogueRequestBody: Codable {
    let message: String
    let sessionId: UUID

    enum CodingKeys: String, CodingKey {
        case message
        case sessionId = "session_id"
    }
}

struct DialogueMessagesResponse: Codable {
    let messages: [DialogueViewModel.DialogueMessage]
    let dialogueSessionId: UUID

    enum CodingKeys: String, CodingKey {
        case messages
        case dialogueSessionId = "dialogue_session_id"
    }
}

struct PendingRequestsResponse: Codable {
    let requests: [DialogueViewModel.DialogueRequest]
}

struct DialogueRequestResponse: Codable {
    let success: Bool
    let requestId: UUID
    let dialogueSessionId: UUID

    enum CodingKeys: String, CodingKey {
        case success
        case requestId = "request_id"
        case dialogueSessionId = "dialogue_session_id"
    }
}
