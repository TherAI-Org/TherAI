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
                messages = [] // Clear messages when no session is active
                generateEmptyPrompt()
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var isLoadingHistory: Bool = false
    @Published var emptyPrompt: String = ""

    private let backend = BackendService.shared
    private let authService = AuthService.shared
    private var currentTask: Task<Void, Never>?

    // Cache of messages per session to avoid unnecessary refetches when revisiting
    private struct MessagesCacheEntry {
        let messages: [ChatMessage]
        let lastLoaded: Date
    }
    private var messagesCache: [UUID: MessagesCacheEntry] = [:]
    private let cacheFreshnessSeconds: TimeInterval = 300

    init(sessionId: UUID? = nil) {
        self.sessionId = sessionId
        self.generateEmptyPrompt()
        Task { await loadHistory() }
    }

    // Ensure a personal session id exists, creating one if needed
    func ensureSessionId() async -> UUID? {
        if let sid = sessionId { return sid }
        do {
            guard let accessToken = await authService.getAccessToken() else { return nil }
            let dto = try await backend.createEmptySession(accessToken: accessToken)
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
            return dto.id
        } catch {
            print("[ChatVM] ensureSessionId failed: \(error)")
            return nil
        }
    }

    func loadHistory(force: Bool = false) async {
        do {
            guard let sid = sessionId else { self.messages = []; self.isLoadingHistory = false; return }

            // Cache hit and fresh: use cached messages and skip fetch unless forced
            if !force, let entry = messagesCache[sid] {
                let age = Date().timeIntervalSince(entry.lastLoaded)
                if age < cacheFreshnessSeconds {
                    self.messages = entry.messages
                    self.isLoadingHistory = false
                    return
                }
            }

            // Show spinner only if there is no content to display yet
            if self.messages.isEmpty { self.isLoadingHistory = true }

            guard let accessToken = await authService.getAccessToken() else {
                print("ACCESS_TOKEN: <nil>")
                self.isLoadingHistory = false
                return
            }
            let dtos = try await backend.fetchMessages(sessionId: sid, accessToken: accessToken)
            guard let userId = authService.currentUser?.id else { self.isLoadingHistory = false; return }
            let mapped = dtos.map { ChatMessage(dto: $0, currentUserId: userId) }
            self.messages = mapped

            // Update cache
            messagesCache[sid] = MessagesCacheEntry(messages: mapped, lastLoaded: Date())


        } catch {
            // Optionally keep messages empty on failure
            print("Failed to load history: \(error)")
        }
        self.isLoadingHistory = false
    }

    // Present a session using cache-first strategy
    func presentSession(_ id: UUID) async {
        await MainActor.run { self.sessionId = id }

        // Immediately show cached messages if available
        if let entry = messagesCache[id] {
            await MainActor.run { self.messages = entry.messages }
        } else {
            await MainActor.run { self.messages = [] }
        }

        // If fresh cache, don't refetch
        let isFresh: Bool = {
            if let entry = messagesCache[id] {
                return Date().timeIntervalSince(entry.lastLoaded) < cacheFreshnessSeconds
            }
            return false
        }()

        if isFresh {
            await MainActor.run { self.isLoadingHistory = false }
            return
        }

        // Refresh in background (spinner only if there was no cached content)
        await loadHistory(force: true)
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
            print("[ChatVM] stream starting; sessionId=\(String(describing: self.sessionId)) messagesCount=\(self.messages.count)")
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
                var currentSegments: [MessageSegment] = []
                let stream = backend.streamChatMessage(messageToSend, sessionId: self.sessionId, chatHistory: Array(chatHistory), accessToken: accessToken, focusSnippet: self.focusSnippet)
                var sawToolStart = false
                var sawPartnerMessage = false
                var eventCounter = 0
                for await event in stream {
                    guard !Task.isCancelled else { break }
                    eventCounter += 1
                    switch event {
                    case .toolStart:
                        sawToolStart = true
                        await MainActor.run {
                            if self.messages.isEmpty || self.messages.last?.isFromUser == true {
                                self.messages.append(ChatMessage(
                                    content: "",
                                    segments: [],
                                    isFromUser: false,
                                    isPartnerMessage: false,
                                    partnerMessageContent: nil
                                ))
                            }
                            if !self.messages.isEmpty {
                                var newMessages = self.messages
                                let lastIndex = newMessages.count - 1
                                let last = newMessages[lastIndex]
                                let updated = ChatMessage(
                                    id: last.id,
                                    content: last.content,
                                    segments: last.segments,
                                    isFromUser: last.isFromUser,
                                    timestamp: last.timestamp,
                                    isPartnerMessage: last.isPartnerMessage,
                                    partnerMessageContent: last.partnerMessageContent,
                                    partnerDrafts: last.partnerDrafts,
                                    isToolLoading: true
                                )
                                newMessages[lastIndex] = updated
                                self.messages = newMessages
                            }
                            print("[ChatVM] toolStart received; showing loader (no hardcoded intro)")
                        }
                    case .toolArgs:
                        if !sawToolStart {
                            print("[ChatVM] toolArgs before toolStart; loader may be delayed")
                        }
                        break
                    case .toolDone:
                        await MainActor.run {
                            if !self.messages.isEmpty {
                                var newMessages = self.messages
                                let lastIndex = newMessages.count - 1
                                let last = newMessages[lastIndex]
                                let updated = ChatMessage(
                                    id: last.id,
                                    content: last.content,
                                    segments: last.segments,
                                    isFromUser: last.isFromUser,
                                    timestamp: last.timestamp,
                                    isPartnerMessage: last.isPartnerMessage,
                                    partnerMessageContent: last.partnerMessageContent,
                                    partnerDrafts: last.partnerDrafts,
                                    isToolLoading: false
                                )
                                newMessages[lastIndex] = updated
                                self.messages = newMessages
                            }
                            print("[ChatVM] toolDone received; hiding loader (fallback)")
                        }
                    case .session(let sid):
                        if self.sessionId == nil { self.sessionId = sid }
                    case .token(let token):
                        accumulated += token

                        // Update segments properly
                        if !currentSegments.isEmpty, case .text(let existingText) = currentSegments[currentSegments.count - 1] {
                            // Append to existing text segment
                            currentSegments[currentSegments.count - 1] = .text(existingText + token)
                        } else {
                            // Start new text segment or it's the first segment
                            if currentSegments.isEmpty {
                                currentSegments = [.text(token)]
                            } else {
                                // Last segment is partner message, start new text segment
                                currentSegments.append(.text(token))
                            }
                        }

                        await MainActor.run {
                            if !self.messages.isEmpty {
                                let lastIndex = self.messages.count - 1
                                let last = self.messages[lastIndex]

                                let updated = ChatMessage(
                                    id: last.id,
                                    content: accumulated,
                                    segments: currentSegments,
                                    isFromUser: last.isFromUser,
                                    timestamp: last.timestamp,
                                    isPartnerMessage: last.isPartnerMessage,
                                    partnerMessageContent: last.partnerMessageContent,
                                    partnerDrafts: last.partnerDrafts,
                                    isToolLoading: last.isToolLoading
                                )
                                var newMessages = self.messages
                                newMessages[lastIndex] = updated
                                self.messages = newMessages
                                print("[ChatVM] token update length=\(accumulated.count)")
                            }
                        }
                    case .partnerMessage(let text):
                        sawPartnerMessage = true

                        // Add partner message as a segment
                        currentSegments.append(.partnerMessage(text))

                        await MainActor.run {
                            print("[ChatVM] partner_message received len=\(text.count)")
                            // Update the current assistant message with the new segments
                            if self.messages.isEmpty {
                                self.messages.append(ChatMessage.partnerDraft(text))
                                print("[ChatVM] appended standalone partnerDraft (no messages present)")
                                return
                            }
                            var newMessages = self.messages
                            let lastIndex = newMessages.count - 1
                            let last = newMessages[lastIndex]
                            if last.isFromUser == false {
                                var drafts = last.partnerDrafts
                                drafts.append(text)
                                let updated = ChatMessage(
                                    id: last.id,
                                    content: last.content,
                                    segments: currentSegments,
                                    isFromUser: last.isFromUser,
                                    timestamp: last.timestamp,
                                    isPartnerMessage: true,
                                    partnerMessageContent: drafts.first,
                                    partnerDrafts: drafts,
                                    isToolLoading: false
                                )
                                newMessages[lastIndex] = updated
                                self.messages = newMessages
                                print("[ChatVM] appended draft as segment; total segments=\(currentSegments.count)")
                            } else {
                                self.messages.append(ChatMessage.partnerDraft(text))
                                print("[ChatVM] appended partnerDraft after user message (no assistant placeholder)")
                            }
                        }
                    case .done:
                        print("[ChatVM] stream done; sawToolStart=\(sawToolStart) sawPartnerMessage=\(sawPartnerMessage) events=\(eventCounter)")
                        await MainActor.run { self.isLoading = false }
                    case .error(let message):
                        await MainActor.run {
                            if !self.messages.isEmpty {
                                self.messages[self.messages.count - 1] = ChatMessage(content: "Error: \(message)", isFromUser: false)
                            }
                            self.isLoading = false
                        }
                    }
                }

                // Safety: ensure loading state is cleared if stream ends without a .done event
                await MainActor.run {
                    self.isLoading = false
                }
                print("[ChatVM] stream ended loop (Task end); cancelled=\(Task.isCancelled)")

                // Session creation notification is now sent immediately when session is created above
                if let sid = self.sessionId {
                    NotificationCenter.default.post(name: .chatMessageSent, object: nil, userInfo: [
                        "sessionId": sid,
                        "messageContent": messageToSend
                    ])

                    // Refresh sessions to pick up any title changes (e.g., auto-generated titles)
                    NotificationCenter.default.post(name: .chatSessionsNeedRefresh, object: nil)
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

    // Handle Skip: request a new draft only, replacing the block on the current assistant message
    func requestNewPartnerDraft() {
        print("[ChatVM] requestNewPartnerDraft invoked")
        // For now, simply resend the same user prompt to regenerate a new draft via the same stream
        // Optional future: implement a dedicated /chat/draft/stream endpoint to return only partner_message
        // Here we just no-op; UI layer will trigger a resend flow if desired
    }

    func clearChat() {
        messages.removeAll()
        generateEmptyPrompt()
    }

    func generateEmptyPrompt() {
        // Short, varied, therapist-style prompts
        let prompts = [
            "What feels stuck today daddy?",
            "Where would you like to start?",
            "What feels heavy today?",
            "What would feel supportive to talk through?",
            "What’s been on your heart lately?",
            "What you wanna know nigga",
            "What’s asking for your attention?",
            "What’s on your mind today?",
            "What would make today easier?",
            "What’s been weighing on you?",
            "What’s going well—and what isn’t?",
            "What feels most important to share?",
            "What are you hoping to figure out?",
            "Are you singing to me boy?",
            "What would you like space for?",
            "What’s one thing you want to unpack?",
            "What’s been taking up mental space?",
            "What would help you feel grounded?",
            "Are you a good boy?",
            "Just like that babe, dont stop",
            "What’s the story today?",
            "What do you want to get off your chest?",
            "What are you navigating today?",
            "What you wanna know today nigger?"
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

