import Foundation

struct ChatSession: Identifiable, Hashable, Equatable, Codable {
    static let defaultTitle = "New Chat"

    let id: UUID
    var title: String?
    var lastUsedISO8601: String?
    var lastMessageContent: String?

    var displayTitle: String {
        return title ?? Self.defaultTitle
    }

    init(dto: ChatSessionDTO) {
        self.id = dto.id
        self.title = dto.title
        self.lastUsedISO8601 = dto.last_message_at
        self.lastMessageContent = nil
    }

    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ChatSession {
    init(id: UUID, title: String?, lastUsedISO8601: String?, lastMessageContent: String? = nil) {
        self.id = id
        self.title = title
        self.lastUsedISO8601 = lastUsedISO8601
        self.lastMessageContent = lastMessageContent
    }
}