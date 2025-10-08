import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let isPartnerMessage: Bool
    let partnerMessageContent: String?
    let isToolLoading: Bool

    // Initializes a chat message locally
    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        let parsed = Self.parsePartnerMessage(content)
        self.isPartnerMessage = parsed.isPartner
        self.partnerMessageContent = parsed.content
        self.isToolLoading = false
    }

    // Initializes a partner message coming from SSE event
    static func partnerDraft(_ text: String) -> ChatMessage {
        // Render partner draft within assistant bubble and explicitly mark as partner message
        return ChatMessage(
            id: UUID(),
            content: text,
            isFromUser: false,
            timestamp: Date(),
            isPartnerMessage: true,
            partnerMessageContent: text,
            isToolLoading: false
        )
    }

    // Explicit initializer to construct a message with partner flags
    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date(), isPartnerMessage: Bool, partnerMessageContent: String?, isToolLoading: Bool = false) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.isPartnerMessage = isPartnerMessage
        self.partnerMessageContent = partnerMessageContent
        self.isToolLoading = isToolLoading
    }

    // Initializes a chat message from a backend DTO
    init(dto: ChatMessageDTO, currentUserId: UUID) {
        self.id = dto.id
        self.content = dto.content
        self.isFromUser = (dto.user_id == currentUserId) && dto.role == "user"
        self.timestamp = Date()
        let parsed = Self.parsePartnerMessage(dto.content)
        self.isPartnerMessage = parsed.isPartner
        self.partnerMessageContent = parsed.content
        self.isToolLoading = false
    }

    // Extracts a partner-ready message from assistant content.
    // Detection is STRICT: only honors structured annotation JSON persisted by backend.
    // Live streams set partner flags via events; history relies on annotation only.
    static func parsePartnerMessage(_ content: String) -> (isPartner: Bool, content: String?) {
        // Structured annotation: {"_therai": {"type": "partner_draft", "text": "..."}}
        if let data = content.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let therai = obj["_therai"] as? [String: Any],
           let type = therai["type"] as? String,
           type == "partner_draft",
           let text = therai["text"] as? String {
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? (false, nil) : (true, cleaned)
        }
        return (false, nil)
    }
}
