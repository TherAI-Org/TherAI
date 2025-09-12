import SwiftUI
import Supabase
import UIKit

enum SidebarTab {
    case chat
    case profile
}

class SlideOutSidebarViewModel: ObservableObject {

    @Published var isOpen = false
    @Published var selectedTab: SidebarTab = .chat
    @Published var dragOffset: CGFloat = 0
    @Published var showProfileSheet: Bool = false
    @Published var showSettingsSheet: Bool = false
    @Published var showLinkSheet: Bool = false

    // Sidebar sections state
    @Published var isNotificationsExpanded: Bool = false
    @Published var isChatsExpanded: Bool = false

    // Local chat sessions list (simple store for now)
    @Published var sessions: [ChatSession] = []

    // Pending dialogue requests from partner
    @Published var pendingRequests: [DialogueViewModel.DialogueRequest] = []

    init() {}

    // Currently active session shown in ChatView (nil => new unsaved session)
    @Published var activeSessionId: UUID? = nil
    // Changing this forces ChatView to reinitialize
    @Published var chatViewKey: UUID = UUID()

    // Callback for switching to dialogue mode
    var onSwitchToDialogue: (() -> Void)?

    // Callback for refreshing pending requests
    var onRefreshPendingRequests: (() -> Void)?

    func startNewChat() {
        activeSessionId = nil
        chatViewKey = UUID()
    }

    func openSession(_ id: UUID) {
        activeSessionId = id
        chatViewKey = UUID()
    }

    func openPendingRequest(_ request: DialogueViewModel.DialogueRequest) {
        // Accept first, then switch to dialogue once messages are available
        Task { await acceptPendingRequest(request) }
    }

    private func acceptPendingRequest(_ request: DialogueViewModel.DialogueRequest) async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken

            // Check if this request was sent TO the current user (not BY the current user)
            if let currentUserId = AuthService.shared.currentUser?.id,
               request.senderUserId != currentUserId {
                // Accept the request via service and get personal + dialogue ids
                let (partnerSessionId, _) = try await BackendService.shared.markRequestAsAccepted(requestId: request.id, accessToken: accessToken)

                // Ensure the partner's personal session appears in the chat list
                let personalSession = ChatSession(id: partnerSessionId, title: "Chat")

                // Add the dialogue session to the chat sessions list and switch to it
                await MainActor.run {
                    // Remove from pending requests
                    self.pendingRequests.removeAll { $0.id == request.id }

                    // Add personal session if not already present
                    if !self.sessions.contains(where: { $0.id == partnerSessionId }) {
                        self.sessions.insert(personalSession, at: 0)
                    }

                    // Switch to the personal session for this chat
                    self.activeSessionId = partnerSessionId

                    // Expand chats section to show the new session
                    self.isChatsExpanded = true
                }

                // Tell ChatView to switch to dialogue now (will trigger scoped load)
                await MainActor.run { self.onSwitchToDialogue?() }

                // Also refresh from backend to ensure consistency
                await loadPendingRequests()
            }
        } catch {
            print("Failed to accept pending request: \(error)")
        }
    }

    // MARK: - Notifications
    private var observers: [NSObjectProtocol] = []

    deinit {
        for ob in observers { NotificationCenter.default.removeObserver(ob) }
    }

    func startObserving() {
        // Ensure we start with a fresh session (no active session)
        activeSessionId = nil
        chatViewKey = UUID()

        // Initial load of sessions and pending requests
        Task {
            await loadSessions()
            await loadPendingRequests()
        }

        // Session created
        let created = NotificationCenter.default.addObserver(forName: .chatSessionCreated, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let sid = note.userInfo?["sessionId"] as? UUID {
                // Avoid creating a duplicate entry pointing to the dialogue session
                if !self.sessions.contains(where: { $0.id == sid }) {
                    let session = ChatSession(id: sid, title: note.userInfo?["title"] as? String ?? "Chat")
                    self.sessions.insert(session, at: 0)
                }
                self.isChatsExpanded = true
            }
        }
        observers.append(created)

        // Message sent (move session to top if exists)
        let sent = NotificationCenter.default.addObserver(forName: .chatMessageSent, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let sid = note.userInfo?["sessionId"] as? UUID, let idx = self.sessions.firstIndex(where: { $0.id == sid }) {
                let item = self.sessions.remove(at: idx)
                self.sessions.insert(item, at: 0)
            }
        }
        observers.append(sent)
    }

    // MARK: - Load sessions from backend
    func loadSessions() async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            let dtos = try await BackendService.shared.fetchSessions(accessToken: accessToken)
            let mapped = dtos.map { ChatSession(dto: $0) }
            await MainActor.run { self.sessions = mapped }
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    // MARK: - Load pending requests from backend
    func loadPendingRequests() async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            let response = try await BackendService.shared.getPendingRequests(accessToken: accessToken)
            await MainActor.run {
                self.pendingRequests = response.requests
            }
        } catch {
            print("Failed to load pending requests: \(error)")
        }
    }

    func openSidebar() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isOpen = true
            dragOffset = 0
        }
    }

    func closeSidebar() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isOpen = false
            dragOffset = 0
        }
    }

    func toggleSidebar() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isOpen.toggle()
            dragOffset = 0
        }
    }

    func selectTab(_ tab: SidebarTab) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            selectedTab = tab
            isOpen = false
            dragOffset = 0
        }
    }

    func handleDragGesture(_ translation: CGFloat, width: CGFloat) {
        if isOpen {
            let newOffset = max(-width, min(0, translation))
            dragOffset = newOffset
        } else {
            let newOffset = max(0, min(width, translation))
            dragOffset = newOffset
        }
    }

    func handleSwipeGesture(_ translation: CGFloat, velocity: CGFloat, width: CGFloat) {
        let threshold: CGFloat = width * 0.3 // 30% of screen width
        let velocityThreshold: CGFloat = 500

        if isOpen {
            if translation < -threshold || velocity < -velocityThreshold {
                closeSidebar()
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    dragOffset = 0
                }
            }
        } else {
            if translation > threshold || velocity > velocityThreshold {
                openSidebar()
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    dragOffset = 0
                }
            }
        }
    }
}

// Convenience initializer for local session creation
extension ChatSession {
    init(id: UUID = UUID(), title: String?) {
        self.id = id
        self.title = title
    }
}
