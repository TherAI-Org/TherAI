import Foundation
import SwiftUI
import Supabase

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var sessionId: UUID?

    private let backend = BackendService.shared
    private let authService = AuthService.shared

    init(sessionId: UUID? = nil) {
        self.sessionId = sessionId
        Task { await loadHistory() }
    }

    func loadHistory() async {
        do {
            guard let sid = sessionId else { self.messages = []; return }
            let session = try await authService.client.auth.session
            let accessToken = session.accessToken
            let dtos = try await backend.fetchMessages(sessionId: sid, accessToken: accessToken)
            guard let userId = authService.currentUser?.id else { return }
            let mapped = dtos.map { ChatMessage(dto: $0, currentUserId: userId) }
            self.messages = mapped
        } catch {
            // Optionally keep messages empty on failure
            print("Failed to load history: \(error)")
        }
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(content: inputText, isFromUser: true)
        messages.append(userMessage)

        inputText = ""  // Clear input text

        Task {
            do {
                let session = try await authService.client.auth.session
                let accessToken = session.accessToken
                // Build chat history from current messages (excluding the just-added user message)
                let chatHistory = self.messages.dropLast().map { message in
                    ChatHistoryMessage(
                        role: message.isFromUser ? "user" : "assistant",
                        content: message.content
                    )
                }

                let result = try await backend.sendChatMessage(userMessage.content, sessionId: self.sessionId, chatHistory: Array(chatHistory), accessToken: accessToken)
                let wasNew = self.sessionId == nil
                if wasNew { self.sessionId = result.sessionId }
                let aiMessage = ChatMessage(content: result.response, isFromUser: false)
                await MainActor.run {
                    self.messages.append(aiMessage)
                }

                if wasNew, let sid = self.sessionId {
                    NotificationCenter.default.post(name: .chatSessionCreated, object: nil, userInfo: [
                        "sessionId": sid,
                        "title": "Chat"
                    ])
                }
                if let sid = self.sessionId {
                    NotificationCenter.default.post(name: .chatMessageSent, object: nil, userInfo: [
                        "sessionId": sid
                    ])
                }
            } catch {
                let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", isFromUser: false)
                await MainActor.run {
                    self.messages.append(errorMessage)
                }
            }
        }
    }

    func clearChat() {
        messages.removeAll()
    }
}

