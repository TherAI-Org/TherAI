import Foundation
import SwiftUI
import Supabase
import UIKit

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var focusSnippet: String? = nil
    // UI scroll coordination
    @Published var focusTopMessageId: UUID? = nil
    @Published var assistantScrollTargetId: UUID? = nil
    @Published var streamingScrollToken: Int = 0
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
    @Published var isVoiceRecording: Bool = false

    private let backend = BackendService.shared
    private let authService = AuthService.shared
    private var currentTask: Task<Void, Never>?
    private var currentStreamHandleId: UUID?
    private var typingDelayTask: Task<Void, Never>?
    private var receivedAnyAssistantOutput: Bool = false
    private var currentAssistantMessageId: UUID?
    private var isStreaming: Bool = false
    // Track assistant placeholder per session when streaming continues off-screen
    private var assistantMessageIdBySession: [UUID: UUID] = [:]
    // Session currently streaming, to scope the loading indicator to the right chat
    private var currentStreamingSessionId: UUID?
    // Track which partner drafts have been sent
    @Published private(set) var sentPartnerDrafts: Set<String> = []

    // Global UserDefaults key for all sent drafts
    private let globalSentDraftsKey = "globalSentPartnerDrafts"

    // Cache of messages per session to avoid unnecessary refetches when revisiting
    private struct MessagesCacheEntry {
        let messages: [ChatMessage]
        let lastLoaded: Date
    }
    // Static cache that survives ChatViewModel recreation
    private static var sharedMessagesCache: [UUID: MessagesCacheEntry] = [:]
    private var messagesCache: [UUID: MessagesCacheEntry] {
        get { Self.sharedMessagesCache }
        set { Self.sharedMessagesCache = newValue }
    }
    private let cacheFreshnessSeconds: TimeInterval = 300
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?

	// Keep cache in sync so revisiting a chat shows latest live messages
	private func updateCacheForCurrentSession() {
		guard let sid = self.sessionId else { return }
		messagesCache[sid] = MessagesCacheEntry(messages: self.messages, lastLoaded: Date())
	}

    init(sessionId: UUID? = nil) {
        self.sessionId = sessionId
        self.generateEmptyPrompt()

        // Always load persisted sent drafts (they're global now)
        self.loadSentDrafts()

        // Load history on initialization
        Task { [weak self] in
            guard let self = self else { return }
            await self.loadHistory()
        }

        // Observe partner message notifications to refresh when new partner messages arrive
        let partnerReceived = NotificationCenter.default.addObserver(
            forName: .partnerMessageReceived,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self = self else { return }
                guard let notificationSessionId = note.userInfo?["sessionId"] as? UUID else { return }
                // Now we can safely access sessionId since we're on MainActor
                let currentSessionId = self.sessionId
                print("[ChatVM] Received partnerMessageReceived for session \(notificationSessionId), current session: \(String(describing: currentSessionId))")
                // Only refresh if this notification is for our current session
                if notificationSessionId == currentSessionId {
                    print("[ChatVM] Refreshing messages for partner message in session \(notificationSessionId)")
                    // Force refresh to get the newly delivered partner message
                    await self.loadHistory(force: true)
                }
            }
        }
        observers.append(partnerReceived)
    }

    deinit {
        for ob in observers { NotificationCenter.default.removeObserver(ob) }
        refreshTimer?.invalidate()
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

            // Show spinner only if there is no content to display yet AND we're not already showing content
            // This prevents flashing loading state when we already have partner messages
            if self.messages.isEmpty { self.isLoadingHistory = true }

            guard let accessToken = await authService.getAccessToken() else {
                print("ACCESS_TOKEN: <nil>")
                self.isLoadingHistory = false
                return
            }
            let dtos = try await backend.fetchMessages(sessionId: sid, accessToken: accessToken)
            guard let userId = authService.currentUser?.id else { self.isLoadingHistory = false; return }
            var mapped = dtos.map { ChatMessage(dto: $0, currentUserId: userId) }

            // Debug: Log partner received messages
            for msg in mapped {
                if msg.segments.contains(where: { if case .partnerReceived(_) = $0 { return true } else { return false } }) {
                    print("[ChatVM] Found partner_received message in history: \(msg.content.prefix(50))...")
                }
            }
            // Preserve any optimistic partner-received block that hasn't been persisted yet
            if let optimistic = self.messages.last, let optimisticText = optimistic.partnerMessageContent,
               optimistic.segments.contains(where: { if case .partnerReceived(let t) = $0 { return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } else { return false } }) {
                let existsInMapped: Bool = mapped.contains(where: { msg in
                    msg.segments.contains { seg in
                        if case .partnerReceived(let t) = seg { return t == optimisticText } else { return false }
                    }
                })
                if !existsInMapped {
                    mapped.append(optimistic)
                }
            }
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
        await MainActor.run {
            self.sessionId = id
            // Load persisted sent drafts for this session
            self.loadSentDrafts()
            // Start polling for partner messages if we're linked
            self.startPartnerMessagePolling()
            // If a background stream was active for this session, rebind its placeholder for live updates
            if let placeholderId = self.assistantMessageIdBySession[id] {
                self.currentAssistantMessageId = placeholderId
            } else {
                self.currentAssistantMessageId = nil
            }
            // Scope the loading indicator to only the session that is actually streaming
            self.isLoading = (self.currentStreamingSessionId == id)
            self.isAssistantTyping = false

            // CRITICAL: Show cached messages immediately if available, DON'T clear them
            if let entry = self.messagesCache[id], !entry.messages.isEmpty {
                self.messages = entry.messages
                self.isLoadingHistory = false
                return // Exit early - we have cached messages, no need to clear
            } else {
                // Only clear messages if there's no cache
                self.messages = []
            }
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
        // Removed one-time push after send

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
        assistantScrollTargetId = placeholderMessage.id
        streamingScrollToken = 0
        if let sid = self.sessionId {
            assistantMessageIdBySession[sid] = placeholderMessage.id
        }
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
            await MainActor.run { if let sid = self.sessionId { self.currentStreamingSessionId = sid } }
            // Start a background task to keep the stream alive briefly when app backgrounds
            let bgName = await MainActor.run { "chat_stream_" + (self.sessionId?.uuidString ?? "unknown") }
            let bgTask: UIBackgroundTaskIdentifier? = BackgroundTaskManager.shared.begin(name: bgName) { [weak self] in
                guard let self = self else { return }
                // Expired: cancel stream gracefully; UI will persist partials
                Task { @MainActor in
                    ChatStreamManager.shared.cancel(handleId: self.currentStreamHandleId)
                    self.isStreaming = false
                    self.isAssistantTyping = false
                    self.currentStreamingSessionId = nil
                    self.currentAssistantMessageId = nil
                    self.updateCacheForCurrentSession()
                }
            }
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
            // Track which session this stream belongs to; updated once server sends .session
            var streamSessionId: UUID? = self.sessionId
            // Snapshot the on-screen state at stream start to avoid cross-session pollution
            let (initialMessagesForStream, initialAssistantPlaceholderId): ([ChatMessage], UUID?) = await MainActor.run { (self.messages, self.currentAssistantMessageId) }

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
                            let targetSid = streamSessionId ?? self.sessionId
                            guard let sid = targetSid else { return }
                            if sid == self.sessionId {
                                var newMessages = self.messages
                                let idx: Int = {
                                    if let id = self.currentAssistantMessageId,
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    let placeholder = ChatMessage(content: "", isFromUser: false)
                                    newMessages.append(placeholder)
                                    self.currentAssistantMessageId = placeholder.id
                                    if let sid = self.sessionId { self.assistantMessageIdBySession[sid] = placeholder.id }
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
                                if let id = self.currentAssistantMessageId { self.assistantScrollTargetId = id }
                                self.streamingScrollToken &+= 1
                            } else {
                                var newMessages = self.messagesCache[sid]?.messages ?? []
                                let idx: Int = {
                                    if let id = self.assistantMessageIdBySession[sid],
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    let placeholder = ChatMessage(content: "", isFromUser: false)
                                    newMessages.append(placeholder)
                                    self.assistantMessageIdBySession[sid] = placeholder.id
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
                                self.messagesCache[sid] = MessagesCacheEntry(messages: newMessages, lastLoaded: Date())
                            }
                            print("[ChatVM] toolStart received; showing loader (manager)")
                        }
                    case .toolArgs:
                        if !sawToolStart {
                            print("[ChatVM] toolArgs before toolStart; loader may be delayed")
                        }
                    case .toolDone:
                        Task { @MainActor in
                            let targetSid = streamSessionId ?? self.sessionId
                            guard let sid = targetSid else { return }
                            if sid == self.sessionId {
                                var newMessages = self.messages
                                let idx: Int = {
                                    if let id = self.currentAssistantMessageId,
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    let placeholder = ChatMessage(content: "", isFromUser: false)
                                    newMessages.append(placeholder)
                                    self.currentAssistantMessageId = placeholder.id
                                    if let sid = self.sessionId { self.assistantMessageIdBySession[sid] = placeholder.id }
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
                                if let id = self.currentAssistantMessageId { self.assistantScrollTargetId = id }
                                self.streamingScrollToken &+= 1
                            } else {
                                var newMessages = self.messagesCache[sid]?.messages ?? []
                                let idx: Int = {
                                    if let id = self.assistantMessageIdBySession[sid],
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    let placeholder = ChatMessage(content: "", isFromUser: false)
                                    newMessages.append(placeholder)
                                    self.assistantMessageIdBySession[sid] = placeholder.id
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
                                self.messagesCache[sid] = MessagesCacheEntry(messages: newMessages, lastLoaded: Date())
                            }
                            print("[ChatVM] toolDone received; hiding loader (manager)")
                        }
                    case .session(let sid):
                        // Remember which session the stream is tied to; set sessionId only if it was nil
                        streamSessionId = sid
                        Task { @MainActor in
                            if self.sessionId == nil { self.sessionId = sid }
                            // Initialize cache with the stream's starting messages snapshot (not the currently visible chat)
                            self.messagesCache[sid] = MessagesCacheEntry(messages: initialMessagesForStream, lastLoaded: Date())
                            if let placeholderId = initialAssistantPlaceholderId {
                                self.assistantMessageIdBySession[sid] = placeholderId
                            }
                            self.currentStreamingSessionId = sid
                        }
                    case .token(let token):
                        Task { @MainActor in
                            let targetSid = streamSessionId ?? self.sessionId
                            guard let sid = targetSid else { return }
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
                            if sid == self.sessionId {
                                var newMessages = self.messages
                                let idx: Int = {
                                    if let id = self.currentAssistantMessageId,
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    let placeholder = ChatMessage(content: "", isFromUser: false)
                                    newMessages.append(placeholder)
                                    self.currentAssistantMessageId = placeholder.id
                                    if let sid = self.sessionId { self.assistantMessageIdBySession[sid] = placeholder.id }
                                    return newMessages.count - 1
                                }()
                                let last = newMessages[idx]
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
                                newMessages[idx] = updated
                                self.messages = newMessages
                                if let id = self.currentAssistantMessageId { self.assistantScrollTargetId = id }
                                self.streamingScrollToken &+= 1
                                print("[ChatVM] token update length=\(accumulated.count)")
                            } else {
                                var newMessages = self.messagesCache[sid]?.messages ?? []
                                let idx: Int = {
                                    if let id = self.assistantMessageIdBySession[sid],
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    let placeholder = ChatMessage(content: "", isFromUser: false)
                                    newMessages.append(placeholder)
                                    self.assistantMessageIdBySession[sid] = placeholder.id
                                    return newMessages.count - 1
                                }()
                                let last = newMessages[idx]
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
                                newMessages[idx] = updated
                                self.messagesCache[sid] = MessagesCacheEntry(messages: newMessages, lastLoaded: Date())
                            }
                        }
                    case .partnerMessage(let text):
                        Task { @MainActor in
                            let targetSid = streamSessionId ?? self.sessionId
                            guard let sid = targetSid else { return }
                            if !self.receivedAnyAssistantOutput {
                                self.receivedAnyAssistantOutput = true
                                self.typingDelayTask?.cancel()
                                self.isAssistantTyping = false
                            }
                            sawPartnerMessage = true
                            currentSegments.append(.partnerMessage(text))
                            print("[ChatVM] partner_message received len=\(text.count)")
                            if sid == self.sessionId {
                                var newMessages = self.messages
                                let idx: Int = {
                                    if let id = self.currentAssistantMessageId,
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    let placeholder = ChatMessage(content: "", isFromUser: false)
                                    newMessages.append(placeholder)
                                    self.currentAssistantMessageId = placeholder.id
                                    if let sid = self.sessionId { self.assistantMessageIdBySession[sid] = placeholder.id }
                                    return newMessages.count - 1
                                }()
                                let last = newMessages[idx]
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
                                if let id = self.currentAssistantMessageId { self.assistantScrollTargetId = id }
                                self.streamingScrollToken &+= 1
                                print("[ChatVM] appended draft as segment; total segments=\(currentSegments.count)")
                            } else {
                                var newMessages = self.messagesCache[sid]?.messages ?? []
                                let idx: Int = {
                                    if let id = self.assistantMessageIdBySession[sid],
                                       let i = newMessages.firstIndex(where: { $0.id == id }) { return i }
                                    let placeholder = ChatMessage(content: "", isFromUser: false)
                                    newMessages.append(placeholder)
                                    self.assistantMessageIdBySession[sid] = placeholder.id
                                    return newMessages.count - 1
                                }()
                                let last = newMessages[idx]
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
                                self.messagesCache[sid] = MessagesCacheEntry(messages: newMessages, lastLoaded: Date())
                            }
                        }
                    case .done:
                        print("[ChatVM] stream done (manager); sawToolStart=\(sawToolStart) sawPartnerMessage=\(sawPartnerMessage) events=\(eventCounter)")
                        let targetSid = streamSessionId ?? self.sessionId
                        if let sid = targetSid, sid != self.sessionId {
                            // Background stream finished: persist cache and clear per-session placeholder id
                            Task { @MainActor in
                                if let arr = self.messagesCache[sid]?.messages {
                                    self.messagesCache[sid] = MessagesCacheEntry(messages: arr, lastLoaded: Date())
                                }
                                self.assistantMessageIdBySession[sid] = nil
                                if self.currentStreamingSessionId == sid { self.currentStreamingSessionId = nil }
                            }
                        } else {
                            Task { @MainActor in self.isLoading = false; self.isAssistantTyping = false; self.isStreaming = false }
                            Task { @MainActor in self.currentAssistantMessageId = nil }
                            Task { @MainActor in self.currentStreamingSessionId = nil }
                            Task { @MainActor in self.focusTopMessageId = nil }
                            if let sid = self.sessionId {
                                Task { @MainActor in
                                    self.messagesCache[sid] = MessagesCacheEntry(messages: self.messages, lastLoaded: Date())
                                }
                                NotificationCenter.default.post(name: .chatMessageSent, object: nil, userInfo: [
                                    "sessionId": sid,
                                    "messageContent": messageToSend
                                ])
                                NotificationCenter.default.post(name: .chatSessionsNeedRefresh, object: nil)
                            }
                            BackgroundTaskManager.shared.end(bgTask)
                        }
                    case .error(let message):
                        Task { @MainActor in
                            let targetSid = streamSessionId ?? self.sessionId
                            if let sid = targetSid, sid != self.sessionId {
                                var newMessages = self.messagesCache[sid]?.messages ?? []
                                if !newMessages.isEmpty {
                                    newMessages[newMessages.count - 1] = ChatMessage(content: "Error: \(message)", isFromUser: false)
                                } else {
                                    newMessages.append(ChatMessage(content: "Error: \(message)", isFromUser: false))
                                }
                                self.messagesCache[sid] = MessagesCacheEntry(messages: newMessages, lastLoaded: Date())
                                self.assistantMessageIdBySession[sid] = nil
                            } else {
                                if !self.messages.isEmpty {
                                    self.messages[self.messages.count - 1] = ChatMessage(content: "Error: \(message)", isFromUser: false)
                                }
                                self.isLoading = false
                                self.isAssistantTyping = false
                                self.isStreaming = false
                                self.currentStreamingSessionId = nil
                                self.updateCacheForCurrentSession()
                            }
                            BackgroundTaskManager.shared.end(bgTask)
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

    // Start polling for partner messages every few seconds
    private func startPartnerMessagePolling() {
        refreshTimer?.invalidate()
        // Only poll if we have a session
        guard sessionId != nil else { return }

        // Poll every 3 seconds for new messages
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard self.sessionId != nil else { return }

                // Don't refresh if we're currently streaming
                guard !self.isStreaming else { return }

                print("[ChatVM] Polling for new partner messages...")
                await self.loadHistory(force: true)
            }
        }
    }

    private func stopPartnerMessagePolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // Voice recording methods
    func startVoiceRecording() {
        isVoiceRecording = true
    }

    func stopVoiceRecording(withTranscription transcription: String) {
        isVoiceRecording = false
        // Don't automatically send - let user edit and send manually
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

    // Inject an accepted partner request instantly into the UI without waiting for fetch
    @MainActor
    func showPartnerAcceptanceInstant(sessionId targetSessionId: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let optimistic = ChatMessage(
            content: "",
            segments: [.partnerReceived(trimmed)],
            isFromUser: false,
            isPartnerMessage: true,
            partnerMessageContent: trimmed,
            partnerDrafts: [trimmed],
            isToolLoading: false
        )

        if self.sessionId == targetSessionId {
            // Deduplicate if the same partner message is already present at the end
            if let last = self.messages.last, last.partnerMessageContent == trimmed, last.isPartnerMessage {
                self.isLoadingHistory = false
                self.assistantScrollTargetId = last.id
                self.streamingScrollToken &+= 1
                updateCacheForCurrentSession()
                return
            }
            self.messages.append(optimistic)
            self.isLoadingHistory = false
            self.assistantScrollTargetId = optimistic.id
            self.streamingScrollToken &+= 1
            updateCacheForCurrentSession()
        } else {
            // Update cache so when the session is opened it's already populated
            var entry = self.messagesCache[targetSessionId]?.messages ?? []
            if let last = entry.last, last.partnerMessageContent == trimmed, last.isPartnerMessage {
                self.messagesCache[targetSessionId] = MessagesCacheEntry(messages: entry, lastLoaded: Date())
            } else {
                entry.append(optimistic)
                self.messagesCache[targetSessionId] = MessagesCacheEntry(messages: entry, lastLoaded: Date())
            }
        }
    }

    // Preload partner message into cache before navigation to ensure first render has it
    @MainActor
    func preloadPartnerMessageIntoCache(sessionId: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let partnerMessage = ChatMessage.partnerReceived(trimmed)
        var messages = self.messagesCache[sessionId]?.messages ?? []

        // Only add if not already present
        let alreadyExists = messages.contains { msg in
            msg.partnerMessageContent == trimmed && msg.isPartnerMessage
        }

        if !alreadyExists {
            messages.append(partnerMessage)
            self.messagesCache[sessionId] = MessagesCacheEntry(messages: messages, lastLoaded: Date())
        }

        // ALSO set messages immediately if this is the current session
        if self.sessionId == sessionId {
            self.messages = messages
            self.isLoadingHistory = false
        }
    }

    // Pre-cache a partner message before navigating to ensure it appears instantly
    @MainActor
    static func preCachePartnerMessage(sessionId: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Create the partner message
        let partnerMessage = ChatMessage.partnerReceived(trimmed)

        // Store it in the shared cache so it's immediately available when the session loads
        sharedMessagesCache[sessionId] = MessagesCacheEntry(
            messages: [partnerMessage],
            lastLoaded: Date()
        )
    }

    // Mark a partner draft as sent using stable content identifier
    func markPartnerDraftAsSent(messageContent: String) {
        guard let sessionId = sessionId else { return }
        // Create a globally unique key combining session ID and content snippet
        let contentKey = String(messageContent.prefix(100))
        let key = "\(sessionId.uuidString)_\(contentKey)"
        sentPartnerDrafts.insert(key)

        // Persist to UserDefaults globally
        UserDefaults.standard.set(Array(sentPartnerDrafts), forKey: globalSentDraftsKey)
    }

    // Check if a partner draft has been sent using stable content identifier
    func isPartnerDraftSent(messageContent: String) -> Bool {
        guard let sessionId = sessionId else { return false }
        // Create a globally unique key combining session ID and content snippet
        let contentKey = String(messageContent.prefix(100))
        let key = "\(sessionId.uuidString)_\(contentKey)"
        return sentPartnerDrafts.contains(key)
    }

    // Load all persisted sent drafts (globally)
    private func loadSentDrafts() {
        if let savedDrafts = UserDefaults.standard.stringArray(forKey: globalSentDraftsKey) {
            sentPartnerDrafts = Set(savedDrafts)
        } else {
            sentPartnerDrafts = []
        }
    }
}

