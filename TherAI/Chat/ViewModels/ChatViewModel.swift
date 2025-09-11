import Foundation
import SwiftUI
import Supabase

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var sessionId: UUID?
    @Published var isLoading: Bool = false

    private let backend = BackendService.shared
    private let authService = AuthService.shared
    private var currentTask: Task<Void, Never>?

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

        let messageToSend = inputText
        inputText = ""  // Clear input text
        isLoading = true

        // Cancel any existing task (this allows interrupting current AI response)
        currentTask?.cancel()
        
        // Add placeholder AI message that will be replaced or removed
        let placeholderMessage = ChatMessage(content: "", isFromUser: false)
        messages.append(placeholderMessage)
        
        currentTask = Task {
            do {
                let session = try await authService.client.auth.session
                let accessToken = session.accessToken
                // Build chat history from current messages (excluding the just-added user message and placeholder)
                let chatHistory = self.messages.dropLast(2).map { message in
                    ChatHistoryMessage(
                        role: message.isFromUser ? "user" : "assistant",
                        content: message.content
                    )
                }

                let result = try await backend.sendChatMessage(messageToSend, sessionId: self.sessionId, chatHistory: Array(chatHistory), accessToken: accessToken)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { 
                    await MainActor.run {
                        // Remove the placeholder message if cancelled
                        if !self.messages.isEmpty && self.messages.last?.content.isEmpty == true {
                            self.messages.removeLast()
                        }
                    }
                    return 
                }
                
                let wasNew = self.sessionId == nil
                if wasNew { self.sessionId = result.sessionId }
                
                await MainActor.run {
                    // Replace the placeholder with the actual response
                    if !self.messages.isEmpty {
                        self.messages[self.messages.count - 1] = ChatMessage(content: result.response, isFromUser: false)
                    }
                    self.isLoading = false
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
                // Check if task was cancelled
                guard !Task.isCancelled else { 
                    await MainActor.run {
                        // Remove the placeholder message if cancelled
                        if !self.messages.isEmpty && self.messages.last?.content.isEmpty == true {
                            self.messages.removeLast()
                        }
                    }
                    return 
                }
                
                let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", isFromUser: false)
                await MainActor.run {
                    // Replace the placeholder with error message
                    if !self.messages.isEmpty {
                        self.messages[self.messages.count - 1] = errorMessage
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func stopGeneration() {
        currentTask?.cancel()
        isLoading = false
        
        // Remove the placeholder AI message if it exists
        if !messages.isEmpty && messages.last?.content.isEmpty == true {
            messages.removeLast()
        }
    }

    func clearChat() {
        messages.removeAll()
    }
}

