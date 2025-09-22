import SwiftUI
import Supabase

class ChatSessionsViewModel: ObservableObject {

    @Published var sessions: [ChatSession] = []
    @Published var isLoadingSessions: Bool = false
    @Published var pendingRequests: [DialogueViewModel.DialogueRequest] = []
    @Published var activeSessionId: UUID? = nil
    @Published var chatViewKey: UUID = UUID()

    var onSwitchToDialogue: (() -> Void)?
    var onRefreshPendingRequests: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

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

    func openPendingRequest(_ request: DialogueViewModel.DialogueRequest) {
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
                let title = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalTitle = title?.isEmpty == true ? nil : title
                return ChatSession(id: dto.id, title: finalTitle, lastUsedISO8601: dto.last_message_at)
            }
            await MainActor.run {
                self.sessions = mapped
                self.isLoadingSessions = false
                print("📱 Updated local sessions list with \(mapped.count) sessions")
                if self.activeSessionId == nil, let first = mapped.first {
                    self.activeSessionId = first.id
                }
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

    func deleteSession(_ id: UUID) async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            try await BackendService.shared.deleteSession(sessionId: id, accessToken: accessToken)

            await MainActor.run {
                self.sessions.removeAll { $0.id == id }
                if self.activeSessionId == id {
                    self.activeSessionId = self.sessions.first?.id
                }
                self.saveCachedSessions()
            }
        } catch {
            print("❌ Failed to delete session: \(error)")
        }
    }

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

    func startObserving() {
        activeSessionId = nil
        chatViewKey = UUID()

        Task {
            await loadSessions()
            await loadPendingRequests()
        }

        // Session created
        let created = NotificationCenter.default.addObserver(forName: .chatSessionCreated, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let sid = note.userInfo?["sessionId"] as? UUID {
                if !self.sessions.contains(where: { $0.id == sid }) {
                    let session = ChatSession(id: sid, title: note.userInfo?["title"] as? String ?? "Chat", lastUsedISO8601: nil, lastMessageContent: nil)
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
    }

    private func acceptPendingRequest(_ request: DialogueViewModel.DialogueRequest) async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken

            if let currentUserId = AuthService.shared.currentUser?.id,
               request.senderUserId != currentUserId {
                let (partnerSessionId, _) = try await BackendService.shared.markRequestAsAccepted(requestId: request.id, accessToken: accessToken)

                let personalSession = ChatSession(id: partnerSessionId, title: "Chat", lastUsedISO8601: nil)

                await MainActor.run {
                    self.pendingRequests.removeAll { $0.id == request.id }

                    if !self.sessions.contains(where: { $0.id == partnerSessionId }) {
                        self.sessions.insert(personalSession, at: 0)
                    }

                    self.activeSessionId = partnerSessionId
                }

                await MainActor.run { self.onSwitchToDialogue?() }
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

