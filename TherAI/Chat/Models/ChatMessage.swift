import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let isPartnerMessage: Bool
    let partnerMessageContent: String?

    // Initializes a chat message locally
    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        let parsed = Self.parsePartnerMessage(content)
        self.isPartnerMessage = parsed.isPartner
        self.partnerMessageContent = parsed.content
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
    }

    // Extracts the clean partner message from the formatted content
    static func parsePartnerMessage(_ content: String) -> (isPartner: Bool, content: String?) {
        let marker = "💬 **Message for your partner:**"
        guard content.contains(marker) else { return (false, nil) }

        let lines = content.components(separatedBy: .newlines)
        var began = false
        var body: [String] = []
        for line in lines {
            if line.contains(marker) { began = true; continue }
            if began {
                // skip heading-like markdown or blank-only decoration
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("**") { continue }
                // ignore any legacy footer if present
                if trimmed.localizedCaseInsensitiveContains("this message is ready") { break }
                body.append(line)
            }
        }
        let cleaned = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (true, cleaned.isEmpty ? nil : cleaned)
    }
}
