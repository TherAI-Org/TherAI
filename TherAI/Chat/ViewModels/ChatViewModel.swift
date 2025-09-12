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
    private var fallbackTask: Task<Void, Never>?

    init(sessionId: UUID? = nil) {
        self.sessionId = sessionId
        Task { await loadHistory() }
    }

    func loadHistory() async {
        do {
            guard let sid = sessionId else { self.messages = []; return }
            guard let accessToken = await authService.getAccessToken() else {
                print("ACCESS_TOKEN: <nil>")
                return
            }
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

        let wasNewSession = (self.sessionId == nil)
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            guard let accessToken = await authService.getAccessToken() else {
                print("ACCESS_TOKEN: <nil>")
                return
            }
                // Build chat history from current messages (excluding the just-added user message and placeholder)
                let chatHistory = self.messages.dropLast(2).map { message in
                    ChatHistoryMessage(
                        role: message.isFromUser ? "user" : "assistant",
                        content: message.content
                    )
                }

                var accumulated = ""
                let stream = backend.streamChatMessage(messageToSend, sessionId: self.sessionId, chatHistory: Array(chatHistory), accessToken: accessToken)

                // Fallback timer: if no token received after 6s, call non-stream API
                self.fallbackTask?.cancel()
                self.fallbackTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    guard let self = self, !Task.isCancelled else { return }
                    if let result = try? await self.backend.sendChatMessage(messageToSend, sessionId: self.sessionId, chatHistory: Array(chatHistory), accessToken: accessToken) {
                        await MainActor.run {
                            if self.sessionId == nil { self.sessionId = result.sessionId }
                            if !self.messages.isEmpty {
                                let last = self.messages[self.messages.count - 1]
                                self.messages[self.messages.count - 1] = ChatMessage(id: last.id, content: result.response, isFromUser: last.isFromUser, timestamp: last.timestamp)
                            }
                            self.isLoading = false
                        }
                    } else {
                        await MainActor.run {
                            if !self.messages.isEmpty {
                                let last = self.messages[self.messages.count - 1]
                                self.messages[self.messages.count - 1] = ChatMessage(id: last.id, content: "Error: request failed", isFromUser: last.isFromUser, timestamp: last.timestamp)
                            }
                            self.isLoading = false
                        }
                    }
                }

                for await event in stream {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .session(let sid):
                        if self.sessionId == nil { self.sessionId = sid }
                        self.fallbackTask?.cancel()
                    case .token(let token):
                        self.fallbackTask?.cancel()
                        accumulated += token
                        await MainActor.run {
                            if !self.messages.isEmpty {
                                let lastIndex = self.messages.count - 1
                                let last = self.messages[lastIndex]
                                let updated = ChatMessage(id: last.id, content: accumulated, isFromUser: last.isFromUser, timestamp: last.timestamp)
                                var newMessages = self.messages
                                newMessages[lastIndex] = updated
                                self.messages = newMessages
                                print("[ChatVM] token update length=\(accumulated.count)")
                            }
                        }
                    case .done:
                        await MainActor.run { self.isLoading = false }
                        self.fallbackTask?.cancel()
                    case .error(let message):
                        await MainActor.run {
                            if !self.messages.isEmpty {
                                self.messages[self.messages.count - 1] = ChatMessage(content: "Error: \(message)", isFromUser: false)
                            }
                            self.isLoading = false
                        }
                        self.fallbackTask?.cancel()
                    default:
                        break
                    }
                }

                if wasNewSession, let sid = self.sessionId {
                    NotificationCenter.default.post(name: .chatSessionCreated, object: nil, userInfo: [
                        "sessionId": sid,
                        "title": "Session"
                    ])
                }
                if let sid = self.sessionId {
                    NotificationCenter.default.post(name: .chatMessageSent, object: nil, userInfo: [
                        "sessionId": sid
                    ])
                }
        }
    }

    func stopGeneration() {
        currentTask?.cancel()
        fallbackTask?.cancel()
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

