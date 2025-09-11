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
    
    // Rename dialog state
    @Published var showRenameDialog: Bool = false
    @Published var renameSessionId: UUID? = nil
    @Published var renameText: String = ""

    init() {}

    // Currently active session shown in ChatView (nil => new unsaved session)
    @Published var activeSessionId: UUID? = nil
    // Changing this forces ChatView to reinitialize
    @Published var chatViewKey: UUID = UUID()

    func startNewChat() {
        activeSessionId = nil
        chatViewKey = UUID()
    }

    func openSession(_ id: UUID) {
        activeSessionId = id
        chatViewKey = UUID()
    }

    // MARK: - Notifications
    private var observers: [NSObjectProtocol] = []

    deinit {
        for ob in observers { NotificationCenter.default.removeObserver(ob) }
    }

    func startObserving() {
        // Initial load of sessions
        Task { await loadSessions() }

        // Session created
        let created = NotificationCenter.default.addObserver(forName: .chatSessionCreated, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let sid = note.userInfo?["sessionId"] as? UUID {
                let session = ChatSession(id: sid, title: note.userInfo?["title"] as? String ?? "Chat")
                if !self.sessions.contains(session) {
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
            let mapped = dtos.map { dto in
                // Fix empty string titles to be nil so UI shows "Chat"
                let title = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalTitle = title?.isEmpty == true ? nil : title
                return ChatSession(id: dto.id, title: finalTitle)
            }
            await MainActor.run { self.sessions = mapped }
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    // MARK: - Refresh sessions (for pull-to-refresh)
    func refreshSessions() async {
        await loadSessions()
    }
    
    // MARK: - Delete session
    func deleteSession(_ sessionId: UUID) async {
        print("🗑️ Starting delete for session: \(sessionId)")
        
        // Remove from local sessions list immediately
        await MainActor.run {
            let beforeCount = self.sessions.count
            self.sessions.removeAll { $0.id == sessionId }
            let afterCount = self.sessions.count
            print("📱 Removed session from local list: \(beforeCount) -> \(afterCount)")
            
            // If we deleted the active session, clear it
            if self.activeSessionId == sessionId {
                print("🔄 Clearing active session")
                self.activeSessionId = nil
                self.chatViewKey = UUID()
            }
        }
        
        // Try to delete from backend (but don't fail if it doesn't work)
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            print("🔑 Got access token, calling backend...")
            
            try await BackendService.shared.deleteSession(sessionId: sessionId, accessToken: accessToken)
            print("✅ Backend deletion successful")
        } catch {
            print("⚠️ Backend deletion failed (but local deletion succeeded): \(error)")
            // Don't show error to user since local deletion worked
        }
    }
    
    // MARK: - Rename session
    func renameSession(_ sessionId: UUID, newTitle: String) async {
        print("✏️ Starting rename for session: \(sessionId) to '\(newTitle)'")
        
        // Update local sessions list immediately
        await MainActor.run {
            if let index = self.sessions.firstIndex(where: { $0.id == sessionId }) {
                // If newTitle is empty, set to nil so UI shows "Chat"
                self.sessions[index].title = newTitle.isEmpty ? nil : newTitle
                print("📱 Updated local session title: '\(newTitle.isEmpty ? "nil (will show 'Chat')" : newTitle)'")
            }
        }
        
        // Try to rename on backend (but don't fail if it doesn't work)
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            print("🔑 Got access token, calling backend...")
            
            try await BackendService.shared.renameSession(sessionId: sessionId, newTitle: newTitle, accessToken: accessToken)
            print("✅ Backend rename successful")
        } catch {
            print("⚠️ Backend rename failed (but local rename succeeded): \(error)")
            // Don't show error to user since local rename worked
        }
    }
    
    // MARK: - Rename dialog helpers
    func startRename(sessionId: UUID, currentTitle: String?) {
        renameSessionId = sessionId
        renameText = currentTitle ?? ""
        showRenameDialog = true
    }
    
    func confirmRename() {
        guard let sessionId = renameSessionId else {
            return
        }
        
        let trimmedTitle = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? nil : trimmedTitle
        
        Task {
            await renameSession(sessionId, newTitle: finalTitle ?? "")
        }
        
        showRenameDialog = false
        renameSessionId = nil
        renameText = ""
    }
    
    func cancelRename() {
        showRenameDialog = false
        renameSessionId = nil
        renameText = ""
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
