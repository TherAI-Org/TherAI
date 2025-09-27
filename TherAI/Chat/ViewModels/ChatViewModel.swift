import Foundation
import SwiftUI
import Supabase

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var focusSnippet: String? = nil
    @Published var sessionId: UUID? {
        didSet {
            if sessionId == nil {
                generateEmptyPrompt()
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var emptyPrompt: String = ""

    private let backend = BackendService.shared
    private let authService = AuthService.shared
    private var currentTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?

    init(sessionId: UUID? = nil) {
        self.sessionId = sessionId
        self.generateEmptyPrompt()
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

            // Trigger scroll to bottom after loading messages - multiple attempts to ensure it works
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .scrollToBottom, object: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NotificationCenter.default.post(name: .scrollToBottom, object: nil)
            }
        } catch {
            // Optionally keep messages empty on failure
            print("Failed to load history: \(error)")
        }
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Add user message (trimmed for display)
        let trimmedMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = ChatMessage(content: trimmedMessage, isFromUser: true)
        messages.append(userMessage)

        let messageToSend = trimmedMessage
        inputText = ""  // Clear input text
        isLoading = true

        // Cancel any existing task (this allows interrupting current AI response)
        currentTask?.cancel()

        // Add placeholder AI message that will be replaced or removed
        let placeholderMessage = ChatMessage(content: "", isFromUser: false)
        messages.append(placeholderMessage)

        let _ = (self.sessionId == nil) // Track if this was a new session
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            guard let accessToken = await authService.getAccessToken() else {
                print("ACCESS_TOKEN: <nil>")
                return
            }
                // Ensure we have a stable session id before sending to avoid backend auto-creating new sessions
                if self.sessionId == nil {
                    do {
                        let dto = try await self.backend.createEmptySession(accessToken: accessToken)
                        await MainActor.run {
                            self.sessionId = dto.id
                            // Notify immediately when session is created, with timestamp and message preview
                            let currentTime = ISO8601DateFormatter().string(from: Date())
                            NotificationCenter.default.post(name: .chatSessionCreated, object: nil, userInfo: [
                                "sessionId": dto.id,
                                "title": ChatSession.defaultTitle,
                                "lastUsedISO8601": currentTime,
                                "lastMessageContent": messageToSend
                            ])
                        }
                        print("[ChatVM] Pre-created personal session id=\(dto.id) before streaming send")
                    } catch {
                        print("[ChatVM] Failed to pre-create session: \(error)")
                    }
                }

                // Build chat history from current messages (excluding the just-added user message and placeholder)
                let chatHistory = self.messages.dropLast(2).map { message in
                    ChatHistoryMessage(
                        role: message.isFromUser ? "user" : "assistant",
                        content: message.content
                    )
                }

                var accumulated = ""
                let stream = backend.streamChatMessage(messageToSend, sessionId: self.sessionId, chatHistory: Array(chatHistory), accessToken: accessToken, focusSnippet: self.focusSnippet)

                // Fallback timer: if no token received after 6s, call non-stream API
                self.fallbackTask?.cancel()
                self.fallbackTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    guard let self = self, !Task.isCancelled else { return }
                    if let result = try? await self.backend.sendChatMessage(messageToSend, sessionId: self.sessionId, chatHistory: Array(chatHistory), accessToken: accessToken, focusSnippet: self.focusSnippet) {
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

                // Safety: ensure loading state is cleared if stream ends without a .done event
                self.fallbackTask?.cancel()
                await MainActor.run {
                    self.isLoading = false
                }

                // Session creation notification is now sent immediately when session is created above
                if let sid = self.sessionId {
                    NotificationCenter.default.post(name: .chatMessageSent, object: nil, userInfo: [
                        "sessionId": sid,
                        "messageContent": messageToSend
                    ])
                }
        }
    }

    func generateInsightFromDialogueMessage(message: DialogueViewModel.DialogueMessage, sourceSessionId: UUID? = nil) async {
        // Stream an assistant insight into Personal chat using backend insight endpoints
        isLoading = true

        do {
            guard let accessToken = await authService.getAccessToken() else {
                print("ACCESS_TOKEN: <nil>")
                isLoading = false
                return
            }

            // Ensure we have a personal session id to attach the insight to
            if self.sessionId == nil {
                if let sid = sourceSessionId {
                    self.sessionId = sid
                } else {
                    do {
                        let dto = try await self.backend.createEmptySession(accessToken: accessToken)
                        await MainActor.run {
                            self.sessionId = dto.id
                            let currentTime = ISO8601DateFormatter().string(from: Date())
                            NotificationCenter.default.post(name: .chatSessionCreated, object: nil, userInfo: [
                                "sessionId": dto.id,
                                "title": ChatSession.defaultTitle,
                                "lastUsedISO8601": currentTime,
                                "lastMessageContent": ""
                            ])
                        }
                        print("[ChatVM] Auto-created session for insight: \(dto.id)")
                    } catch {
                        print("[ChatVM] Failed to auto-create session for insight: \(error)")
                    }
                }
            }

            // Add placeholder AI message that will be filled by stream
            let placeholderMessage = ChatMessage(content: "", isFromUser: false)
            messages.append(placeholderMessage)

            var accumulated = ""
            let stream = backend.streamDialogueInsight(
                sourceSessionId: self.sessionId!,
                dialogueMessageId: message.id,
                dialogueMessageContent: message.content,
                accessToken: accessToken
            )

            // Fallback to non-stream endpoint if no tokens after 6s
            self.fallbackTask?.cancel()
            self.fallbackTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard let self = self, !Task.isCancelled else { return }
                if let result = try? await self.backend.requestDialogueInsight(
                    sourceSessionId: self.sessionId!,
                    dialogueMessageId: message.id,
                    dialogueMessageContent: message.content,
                    accessToken: accessToken
                ) {
                    await MainActor.run {
                        if !self.messages.isEmpty {
                            let last = self.messages[self.messages.count - 1]
                            self.messages[self.messages.count - 1] = ChatMessage(id: last.id, content: result, isFromUser: last.isFromUser, timestamp: last.timestamp)
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
                switch event {
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

            // Safety: ensure loading state is cleared if stream ends unexpectedly
            self.fallbackTask?.cancel()
            await MainActor.run { self.isLoading = false }
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
        generateEmptyPrompt()
    }

    func generateEmptyPrompt() {
        // Short, varied, therapist-style prompts
        let prompts = [
            "What’s on your mind today?",
            "Where would you like to start?",
            "What feels heavy today?",
            "What would feel supportive to talk through?",
            "What’s been on your heart lately?",
            "What do you need right now?",
            "What’s asking for your attention?",
            "What feels stuck today?",
            "What would make today easier?",
            "What’s been weighing on you?",
            "What’s going well—and what isn’t?",
            "What feels most important to share?",
            "What are you hoping to figure out?",
            "What’s a small win you want today?",
            "What would you like space for?",
            "What’s one thing you want to unpack?",
            "What’s been taking up mental space?",
            "What would help you feel grounded?",
            "What’s been coming up lately?",
            "What feels unclear right now?",
            "What’s the story today?",
            "What do you want to get off your chest?",
            "What are you navigating today?",
            "What would you like to process?"
        ]

        // Use a seed per new chat so it changes each new session but stays stable per view appearance
        var generator = SystemRandomNumberGenerator()
        if let choice = prompts.randomElement(using: &generator) {
            emptyPrompt = choice
        } else {
            emptyPrompt = "What’s on your mind today?"
        }
    }
}

