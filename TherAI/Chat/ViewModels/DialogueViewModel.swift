import Foundation
import SwiftUI

@MainActor
class DialogueViewModel: ObservableObject {
    @Published var messages: [DialogueMessage] = []
    @Published var pendingRequests: [DialogueRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let backendService = BackendService.shared
    private var acceptedRequestIds: Set<UUID> = []

    // Callback for refreshing pending requests in sidebar
    var onRefreshPendingRequests: (() -> Void)?

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

    func loadDialogueMessages(sourceSessionId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }

            // Require a source session id to scope the dialogue
            guard let sid = sourceSessionId else { throw NSError(domain: "Dialogue", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing source session id"]) }
            let response = try await backendService.getDialogueMessages(accessToken: accessToken, sourceSessionId: sid)
            self.messages = response.messages

            // Don't auto-accept pending requests - they should only be accepted when explicitly clicked
        } catch {
            self.errorMessage = "Failed to load dialogue messages: \(error.localizedDescription)"
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

    func sendToPartner(sessionId: UUID, chatHistory: [ChatHistoryMessage]) async {
        isLoading = true
        errorMessage = nil

        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }

            let request = DialogueRequestBody(
                message: "", // Not used in current implementation
                sessionId: sessionId,
                chatHistory: chatHistory
            )

            // This will trigger auto-linking on the backend
            let result = try await backendService.createDialogueRequest(request, accessToken: accessToken)
            print("[Dialogue] createDialogueRequest success: requestId=\(result.requestId) dialogueSessionId=\(result.dialogueSessionId)")

            // Reload dialogue messages to show the new message
            await loadDialogueMessages(sourceSessionId: sessionId)

        } catch {
            print("[Dialogue] createDialogueRequest failed: \(error.localizedDescription)")

            // Handle specific error cases
            if let nsError = error as NSError? {
                if nsError.domain == "Backend" && nsError.code == 400 {
                    // This is a 400 error from the backend
                    if let errorMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                        if errorMessage.contains("A dialogue request is already pending") {
                            self.errorMessage = "A dialogue request is already pending for this relationship. Please wait for your partner to respond."
                        } else {
                            self.errorMessage = "Failed to send to partner: \(errorMessage)"
                        }
                    } else {
                        self.errorMessage = "Failed to send to partner: \(error.localizedDescription)"
                    }
                } else {
                    self.errorMessage = "Failed to send to partner: \(error.localizedDescription)"
                }
            } else {
                self.errorMessage = "Failed to send to partner: \(error.localizedDescription)"
            }
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
        } catch {
            self.errorMessage = "Failed to mark request as accepted: \(error.localizedDescription)"
        }
    }
}

// MARK: - Backend Models
struct DialogueRequestBody: Codable {
    let message: String
    let sessionId: UUID
    let chatHistory: [ChatHistoryMessage]?

    enum CodingKeys: String, CodingKey {
        case message
        case sessionId = "session_id"
        case chatHistory = "chat_history"
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
