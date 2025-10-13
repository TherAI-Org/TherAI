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
    @Published var isAssistantTyping: Bool = false

    private let backend = BackendService.shared
    private let authService = AuthService.shared
    private var currentTask: Task<Void, Never>?
    private var currentStreamHandleId: UUID?
    private var typingDelayTask: Task<Void, Never>?
    private var receivedAnyAssistantOutput: Bool = false
    private var currentAssistantMessageId: UUID?
    private var isStreaming: Bool = false

    // Cache of messages per session to avoid unnecessary refetches when revisiting
    private struct MessagesCacheEntry {
        let messages: [ChatMessage]
        let lastLoaded: Date
    }
    private var messagesCache: [UUID: MessagesCacheEntry] = [:]
    private let cacheFreshnessSeconds: TimeInterval = 300

	// Keep cache in sync so revisiting a chat shows latest live messages
	private func updateCacheForCurrentSession() {
		guard let sid = self.sessionId else { return }
		messagesCache[sid] = MessagesCacheEntry(messages: self.messages, lastLoaded: Date())
	}

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
        guard !isStreaming else { return }

        // Add user message (trimmed for display)
        let trimmedMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = ChatMessage(content: trimmedMessage, isFromUser: true)
        messages.append(userMessage)

        let messageToSend = trimmedMessage
        inputText = ""  // Clear input text
        isLoading = true
        isAssistantTyping = false
        receivedAnyAssistantOutput = false
        typingDelayTask?.cancel()
        typingDelayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                guard let self = self else { return }
                if self.isLoading && !self.receivedAnyAssistantOutput {
                    self.isAssistantTyping = true
                }
            }
        }

        // Cancel any existing stream (this allows interrupting current AI response)
        ChatStreamManager.shared.cancel(handleId: currentStreamHandleId)
        currentStreamHandleId = nil

        // Add placeholder AI message that will be replaced or removed
        let placeholderMessage = ChatMessage(content: "", isFromUser: false)
        messages.append(placeholderMessage)
        currentAssistantMessageId = placeholderMessage.id
		// Ensure cache reflects the latest local state (user + placeholder)
		updateCacheForCurrentSession()

        let _ = (self.sessionId == nil) // Track if this was a new session
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            guard let accessToken = await authService.getAccessToken() else {
                print("ACCESS_TOKEN: <nil>")
                return
            }
            await MainActor.run { self.isStreaming = true }
            print("[ChatVM] stream starting (manager); sessionId=\(String(describing: self.sessionId)) messagesCount=\(self.messages.count)")
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
            var sawToolStart = false
            var sawPartnerMessage = false
            var eventCounter = 0

            let handleId = ChatStreamManager.shared.startStream(
                params: ChatStreamManager.StartParams(
                    message: messageToSend,
                    sessionId: self.sessionId,
                    chatHistory: Array(chatHistory),
                    accessToken: accessToken,
                    focusSnippet: self.focusSnippet
                ),
                onEvent: { [weak self] event in
                    guard let self = self else { return }
                    eventCounter += 1
                    switch event {
                    case .toolStart:
                        sawToolStart = true
                        Task { @MainActor in
                            // Only toggle loader on the existing assistant placeholder
                            if !self.messages.isEmpty {
                                var newMessages = self.messages
                                let idx: Int = {
                                    if let id = self.currentAssistantMessageId,
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    return newMessages.count - 1
                                }()
                                let last = newMessages[idx]
                                let updated = ChatMessage(
                                    id: last.id,
                                    content: last.content,
                                    segments: last.segments,
                                    isFromUser: false,
                                    timestamp: last.timestamp,
                                    isPartnerMessage: last.isPartnerMessage,
                                    partnerMessageContent: last.partnerMessageContent,
                                    partnerDrafts: last.partnerDrafts,
                                    isToolLoading: true
                                )
                                newMessages[idx] = updated
                                self.messages = newMessages
                            }
                            print("[ChatVM] toolStart received; showing loader (manager)")
                        }
                    case .toolArgs:
                        if !sawToolStart {
                            print("[ChatVM] toolArgs before toolStart; loader may be delayed")
                        }
                    case .toolDone:
                        Task { @MainActor in
                            if !self.messages.isEmpty {
                                var newMessages = self.messages
                                let idx: Int = {
                                    if let id = self.currentAssistantMessageId,
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    return newMessages.count - 1
                                }()
                                let last = newMessages[idx]
                                let updated = ChatMessage(
                                    id: last.id,
                                    content: last.content,
                                    segments: last.segments,
                                    isFromUser: false,
                                    timestamp: last.timestamp,
                                    isPartnerMessage: last.isPartnerMessage,
                                    partnerMessageContent: last.partnerMessageContent,
                                    partnerDrafts: last.partnerDrafts,
                                    isToolLoading: false
                                )
                                newMessages[idx] = updated
                                self.messages = newMessages
                            }
                            print("[ChatVM] toolDone received; hiding loader (manager)")
                        }
                    case .session(let sid):
                        Task { @MainActor in if self.sessionId == nil { self.sessionId = sid } }
                    case .token(let token):
                        Task { @MainActor in
                            if !self.receivedAnyAssistantOutput {
                                self.receivedAnyAssistantOutput = true
                                self.typingDelayTask?.cancel()
                                self.isAssistantTyping = false
                            }
                            // Mutate accumulators on MainActor to serialize updates
                            accumulated += token
                            if !currentSegments.isEmpty, case .text(let existingText) = currentSegments[currentSegments.count - 1] {
                                currentSegments[currentSegments.count - 1] = .text(existingText + token)
                            } else {
                                if currentSegments.isEmpty {
                                    currentSegments = [.text(token)]
                                } else {
                                    currentSegments.append(.text(token))
                                }
                            }
                            if !self.messages.isEmpty {
                                let idx: Int = {
                                    if let id = self.currentAssistantMessageId,
                                       let i = self.messages.firstIndex(where: { $0.id == id }) { return i }
                                    return self.messages.count - 1
                                }()
                                let last = self.messages[idx]
                                let updated = ChatMessage(
                                    id: last.id,
                                    content: accumulated,
                                    segments: currentSegments,
                                    isFromUser: false,
                                    timestamp: last.timestamp,
                                    isPartnerMessage: last.isPartnerMessage,
                                    partnerMessageContent: last.partnerMessageContent,
                                    partnerDrafts: last.partnerDrafts,
                                    isToolLoading: last.isToolLoading
                                )
                                var newMessages = self.messages
                                newMessages[idx] = updated
                                self.messages = newMessages
                                print("[ChatVM] token update length=\(accumulated.count)")
                            }
                        }
                    case .partnerMessage(let text):
                        Task { @MainActor in
                            if !self.receivedAnyAssistantOutput {
                                self.receivedAnyAssistantOutput = true
                                self.typingDelayTask?.cancel()
                                self.isAssistantTyping = false
                            }
                            sawPartnerMessage = true
                            currentSegments.append(.partnerMessage(text))
                            print("[ChatVM] partner_message received len=\(text.count)")
                            if self.messages.isEmpty {
                                self.messages.append(ChatMessage.partnerDraft(text))
                                print("[ChatVM] appended standalone partnerDraft (no messages present)")
                                return
                            }
                            var newMessages = self.messages
                            let idx: Int = {
                                if let id = self.currentAssistantMessageId,
                                   let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                return newMessages.count - 1
                            }()
                            let last = newMessages[idx]
                            if last.isFromUser == false {
                                var drafts = last.partnerDrafts
                                drafts.append(text)
                                let updated = ChatMessage(
                                    id: last.id,
                                    content: last.content,
                                    segments: currentSegments,
                                    isFromUser: false,
                                    timestamp: last.timestamp,
                                    isPartnerMessage: true,
                                    partnerMessageContent: drafts.first,
                                    partnerDrafts: drafts,
                                    isToolLoading: false
                                )
                                newMessages[idx] = updated
                                self.messages = newMessages
                                print("[ChatVM] appended draft as segment; total segments=\(currentSegments.count)")
                            } else {
                                self.messages.append(ChatMessage.partnerDraft(text))
                                print("[ChatVM] appended partnerDraft after user message (no assistant placeholder)")
                            }
                        }
                    case .done:
                        print("[ChatVM] stream done (manager); sawToolStart=\(sawToolStart) sawPartnerMessage=\(sawPartnerMessage) events=\(eventCounter)")
                        Task { @MainActor in self.isLoading = false; self.isAssistantTyping = false; self.isStreaming = false }
                        Task { @MainActor in self.currentAssistantMessageId = nil }
                        // Sessions list refresh
                        if let sid = self.sessionId {
						// Update cache so a quick revisit shows the final assistant reply
						Task { @MainActor in
							self.messagesCache[sid] = MessagesCacheEntry(messages: self.messages, lastLoaded: Date())
						}
                            NotificationCenter.default.post(name: .chatMessageSent, object: nil, userInfo: [
                                "sessionId": sid,
                                "messageContent": messageToSend
                            ])
                            NotificationCenter.default.post(name: .chatSessionsNeedRefresh, object: nil)
                        }
                    case .error(let message):
                        Task { @MainActor in
                            if !self.messages.isEmpty {
                                self.messages[self.messages.count - 1] = ChatMessage(content: "Error: \(message)", isFromUser: false)
                            }
                            self.isLoading = false
                            self.isAssistantTyping = false
                            self.isStreaming = false
						// Keep cache updated even on error so user message persists on revisit
						self.updateCacheForCurrentSession()
                        }
                    }
                },
                onFinish: { [weak self] in
                    Task { @MainActor in
                        self?.isLoading = false
                        self?.isAssistantTyping = false
                        self?.isStreaming = false
                        self?.currentAssistantMessageId = nil
					// Final safeguard to keep cache in sync after stream lifecycle ends
					self?.updateCacheForCurrentSession()
                    }
                }
            )

            await MainActor.run { self.currentStreamHandleId = handleId }
        }
    }



    func stopGeneration() {
        ChatStreamManager.shared.cancel(handleId: currentStreamHandleId)
        currentStreamHandleId = nil
        isLoading = false
        isStreaming = false
        // Keep partial/empty assistant message to avoid disappearance when user stops
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
        // Short, varied, natural prompts that real therapists use to begin conversations
        let prompts = [
            "Where would you like to start?",
            "What's on your mind today?",
            "What would you like to talk about today?",
            "How are things going?",
            "What's been going on?",
            "How have you been?",
            "What's on your mind?",
            "How have things been?",
            "What would you like to discuss?",
            "What brings you here today?",
            "What would be most helpful to focus on today?",
            "Tell me what's been happening",
            "What would you like to work on today?",
            "How are you doing?",
            "What's been on your heart?",
            "How are you feeling today?",
            "Where shall we begin?",
            "What feels most pressing right now?",
            "What's happening for you?",
            "What would you like to explore today?"
        ]

        // Use a seed per new chat so it changes each new session but stays stable per view appearance
        var generator = SystemRandomNumberGenerator()
        if let choice = prompts.randomElement(using: &generator) {
            emptyPrompt = choice
        } else {
            emptyPrompt = "What's on your mind today?"
        }
    }
}

