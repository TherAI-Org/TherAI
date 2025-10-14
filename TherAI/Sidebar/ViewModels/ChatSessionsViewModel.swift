import SwiftUI
import Supabase

class ChatSessionsViewModel: ObservableObject {

    @Published var sessions: [ChatSession] = []
    @Published var isLoadingSessions: Bool = false
    @Published var pendingRequests: [BackendService.PartnerPendingRequest] = []
    @Published var activeSessionId: UUID? = nil
    @Published var chatViewKey: UUID = UUID()
    @Published var myAvatarURL: String? = nil
    @Published var partnerAvatarURL: String? = nil
    @Published var partnerInfo: BackendService.PartnerInfo? = nil
    @Published var avatarsLoaded: Bool = false

    var onRefreshPendingRequests: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private let avatarCacheManager = AvatarCacheManager.shared
    private var handlingPartnerRequestIds: Set<UUID> = []
    private var hasStartedObserving: Bool = false
    private weak var navigationViewModel: SidebarNavigationViewModel?

    @MainActor
    private func findNavigationViewModel() -> SidebarNavigationViewModel? {
        // Return the cached reference if available
        return navigationViewModel
    }

    func setNavigationViewModel(_ navVM: SidebarNavigationViewModel) {
        self.navigationViewModel = navVM
    }

    init() {
        loadCachedSessions()
    }

    deinit {
        for ob in observers { NotificationCenter.default.removeObserver(ob) }
    }

    func startNewChat() {
        activeSessionId = nil
        chatViewKey = UUID()
    }

    func openSession(_ id: UUID) {
        activeSessionId = id
        chatViewKey = UUID()
    }

    func openPendingRequest(_ request: BackendService.PartnerPendingRequest) {
        Task { await acceptPendingRequest(request) }
    }

    func formatLastUsed(_ iso: String?) -> String {
        guard let raw = iso?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "" }

        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]

        let parsed = iso1.date(from: raw) ?? iso2.date(from: raw)
        guard let date = parsed else { return "" }

        let out = DateFormatter()
        out.locale = Locale.current
        out.dateFormat = "dd.MM.yyyy"
        return out.string(from: date)
    }

    func loadSessions() async {
        print("🔄 Loading sessions from backend...")
        do {
            await MainActor.run { self.isLoadingSessions = self.sessions.isEmpty }
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            print("🔑 Got access token, fetching sessions...")
            let dtos = try await BackendService.shared.fetchSessions(accessToken: accessToken)
            print("📋 Fetched \(dtos.count) sessions from backend")
            let mapped = dtos.map { dto in
                return ChatSession(
                    id: dto.id,
                    title: dto.title,
                    lastUsedISO8601: dto.last_message_at,
                    lastMessageContent: dto.last_message_content
                )
            }
            await MainActor.run {
                self.sessions = mapped
                self.isLoadingSessions = false
                print("📱 Updated local sessions list with \(mapped.count) sessions")
                // Don't automatically open the first session - let user choose
                // if self.activeSessionId == nil, let first = mapped.first {
                //     self.activeSessionId = first.id
                // }
                self.saveCachedSessions()
            }
        } catch {
            if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("⏭️ Load sessions cancelled (expected during rapid refresh) — ignoring")
                await MainActor.run { self.isLoadingSessions = false }
                return
            }
            print("❌ Failed to load sessions: \(error)")
            await MainActor.run { self.isLoadingSessions = false }
        }
    }

    func refreshSessions() async {
        await loadSessions()
    }

    func renameSession(_ id: UUID, to newTitle: String?) async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            try await BackendService.shared.renameSession(sessionId: id, title: newTitle, accessToken: accessToken)
            await MainActor.run {
                if let idx = self.sessions.firstIndex(where: { $0.id == id }) {
                    var updated = self.sessions[idx]
                    let trimmed = newTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.title = (trimmed?.isEmpty == false) ? trimmed! : ChatSession.defaultTitle
                    self.sessions[idx] = updated
                    self.saveCachedSessions()
                }
            }
        } catch {
            print("Failed to rename session: \(error)")
        }
    }

    func deleteSession(_ id: UUID) async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            try await BackendService.shared.deleteSession(sessionId: id, accessToken: accessToken)
            await MainActor.run {
                self.sessions.removeAll { $0.id == id }
                if self.activeSessionId == id { self.activeSessionId = nil }
                self.saveCachedSessions()
                NotificationCenter.default.post(name: .relationshipTotalsChanged, object: nil)
            }
        } catch {
            print("Failed to delete session: \(error)")
        }
    }

    func loadPendingRequests() async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            let response = try await BackendService.shared.getPartnerPendingRequests(accessToken: accessToken)
            await MainActor.run {
                self.pendingRequests = response.requests
            }
        } catch {
            print("Failed to load pending requests: \(error)")
        }
    }

    func startObserving() {
        if hasStartedObserving { return }
        hasStartedObserving = true
        activeSessionId = nil
        chatViewKey = UUID()

        Task {
            await loadSessions()
            await loadPendingRequests()
            await loadPairedAvatars()
            await loadPartnerInfo()
            await preloadAvatars()
        }

        // Session created
        let created = NotificationCenter.default.addObserver(forName: .chatSessionCreated, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let sid = note.userInfo?["sessionId"] as? UUID {
                if !self.sessions.contains(where: { $0.id == sid }) {
                    let rawTitle = (note.userInfo?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let title = rawTitle
                    let session = ChatSession(
                        id: sid,
                        title: title,
                        lastUsedISO8601: note.userInfo?["lastUsedISO8601"] as? String,
                        lastMessageContent: note.userInfo?["lastMessageContent"] as? String
                    )
                    self.sessions.insert(session, at: 0)
                }
            }
        }
        observers.append(created)

        // Message sent
        let sent = NotificationCenter.default.addObserver(forName: .chatMessageSent, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let sid = note.userInfo?["sessionId"] as? UUID,
               let messageContent = note.userInfo?["messageContent"] as? String,
               let idx = self.sessions.firstIndex(where: { $0.id == sid }) {
                var item = self.sessions.remove(at: idx)
                item.lastMessageContent = messageContent
                self.sessions.insert(item, at: 0)
            }
        }
        observers.append(sent)

        // Sessions need refresh (e.g., after title generation)
        let needRefresh = NotificationCenter.default.addObserver(forName: .chatSessionsNeedRefresh, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.refreshSessions() }
        }
        observers.append(needRefresh)

        // Avatar changed - reload avatar URLs and preload new avatars
        let avatarChanged = NotificationCenter.default.addObserver(forName: .avatarChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.loadPairedAvatars()
                await self.preloadAvatars()
            }
        }
        observers.append(avatarChanged)

        // Push tapped: open partner request by accepting it and navigating to chat
        let pushTapped = NotificationCenter.default.addObserver(forName: .partnerRequestOpen, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            guard let requestId = note.userInfo?["requestId"] as? UUID else { return }
            // Ensure we're authenticated before processing
            guard AuthService.shared.isAuthenticated else { return }
            // Prevent duplicate processing
            if self.handlingPartnerRequestIds.contains(requestId) { return }
            self.handlingPartnerRequestIds.insert(requestId)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    let session = try await AuthService.shared.client.auth.session
                    let accessToken = session.accessToken
                    // Accept the partner request (backend is idempotent)
                    let partnerSessionId = try await BackendService.shared.acceptPartnerRequest(requestId: requestId, accessToken: accessToken)
                    // Reload sessions before navigating to ensure the session exists in the list
                    await self.loadSessions()
                    // Navigate to the chat and close sidebar
                    self.activeSessionId = partnerSessionId
                    self.chatViewKey = UUID()
                    // Close the sidebar to show the chat
                    if let navVM = self.findNavigationViewModel() {
                        navVM.closeSidebar()
                    }
                    await self.loadPendingRequests()
                } catch {
                    print("Failed to accept partner request: \(error)")
                    // If the request was already accepted, try to find and open the session
                    await self.loadSessions()
                    if let existingSession = self.sessions.first {
                        self.activeSessionId = existingSession.id
                        self.chatViewKey = UUID()
                        // Close the sidebar to show the chat
                        if let navVM = self.findNavigationViewModel() {
                            navVM.closeSidebar()
                        }
                    }
                }
                // Allow future taps after brief window to avoid rapid duplicates
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.handlingPartnerRequestIds.remove(requestId)
                }
            }
        }
        observers.append(pushTapped)

        // Push tapped: open partner session directly on partner message notification
        let partnerMessageTapped = NotificationCenter.default.addObserver(forName: .partnerMessageOpen, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            guard let sessionId = note.userInfo?["sessionId"] as? UUID else { return }
            // Ensure authenticated
            guard AuthService.shared.isAuthenticated else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Make sure sessions list includes this session, then navigate
                await self.loadSessions()
                self.activeSessionId = sessionId
                self.chatViewKey = UUID()
                if let navVM = self.findNavigationViewModel() {
                    navVM.closeSidebar()
                }
            }
        }
        observers.append(partnerMessageTapped)
    }

    func loadPairedAvatars() async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            let res = try await BackendService.shared.fetchPairedAvatars(accessToken: accessToken)
            await MainActor.run {
                self.myAvatarURL = res.me.url
                self.partnerAvatarURL = res.partner.url
            }
        } catch {
            print("Failed to load avatars: \(error)")
        }
    }

    /// Preload avatar images into cache for immediate access
    func preloadAvatars() async {
        var avatarURLs: [String] = []

        // Collect all avatar URLs
        if let myAvatar = myAvatarURL, !myAvatar.isEmpty {
            avatarURLs.append(myAvatar)
        }
        if let partnerAvatar = partnerAvatarURL, !partnerAvatar.isEmpty {
            avatarURLs.append(partnerAvatar)
        }

        // Preload all avatars
        if !avatarURLs.isEmpty {
            await avatarCacheManager.preloadAvatars(urls: avatarURLs)
        }

        await MainActor.run {
            self.avatarsLoaded = true
        }
    }

    /// Get cached avatar image
    func getCachedAvatar(urlString: String?) async -> UIImage? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        return await avatarCacheManager.getCachedImage(urlString: urlString)
    }

    func loadPartnerInfo() async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            let res = try await BackendService.shared.fetchPartnerInfo(accessToken: accessToken)
            await MainActor.run {
                self.partnerInfo = res
            }
        } catch {
            print("Failed to load partner info: \(error)")
        }
    }

    private func acceptPendingRequest(_ request: BackendService.PartnerPendingRequest) async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken

            if let currentUserId = AuthService.shared.currentUser?.id,
               request.sender_user_id != currentUserId {
                let partnerSessionId = try await BackendService.shared.acceptPartnerRequest(requestId: request.id, accessToken: accessToken)

                await MainActor.run {
                    self.pendingRequests.removeAll { $0.id == request.id }
                    self.activeSessionId = partnerSessionId
                    // Notify profile to recompute relationship totals immediately
                    NotificationCenter.default.post(name: .relationshipTotalsChanged, object: nil)
                }

                // Refresh sessions to get the latest data including timestamps
                await loadSessions()
                await loadPendingRequests()
            }
        } catch {
            print("Failed to accept pending request: \(error)")
        }
    }
}

extension ChatSessionsViewModel {
    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("chat_sessions_cache.json")
    }

    private func loadCachedSessions() {
        do {
            let url = cacheURL
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([ChatSession].self, from: data)
            self.sessions = decoded
        } catch {
            print("⚠️ Failed to load cached sessions: \(error)")
        }
    }

    private func saveCachedSessions() {
        do {
            let data = try JSONEncoder().encode(self.sessions)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            print("⚠️ Failed to save cached sessions: \(error)")
        }
    }
}

