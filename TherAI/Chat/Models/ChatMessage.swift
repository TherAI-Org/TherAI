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
        // Check for conversational format (intro + message)
        // Look for patterns that suggest this is a partner message with conversational intro
        let conversationalPatterns = [
            "here's a message for your",
            "here's what you can say",
            "here's something you can tell",
            "yes, of course!",
            "i'd be happy to help!",
            "absolutely!",
            "of course!"
        ]

        let lowercasedContent = content.lowercased()
        let hasConversationalIntro = conversationalPatterns.contains { pattern in
            lowercasedContent.contains(pattern)
        }

        if hasConversationalIntro {
            // This is likely a conversational format - extract the actual message
            let lines = content.components(separatedBy: .newlines)
            var messageLines: [String] = []
            var foundMessage = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }

                let lowercasedLine = trimmed.lowercased()

                // Skip conversational intro lines
                let isIntroLine = conversationalPatterns.contains { pattern in
                    lowercasedLine.contains(pattern)
                }

                // Skip AI footer lines
                let isFooterLine = lowercasedLine.contains("feel free to tweak") ||
                                  lowercasedLine.contains("you can adjust") ||
                                  lowercasedLine.contains("modify if needed") ||
                                  lowercasedLine.contains("---") ||
                                  lowercasedLine.contains("tap the button")

                if isIntroLine {
                    // Skip intro lines, start looking for message
                    continue
                }

                if isFooterLine {
                    // Stop collecting when we hit footer lines
                    break
                }

                if !foundMessage && !isIntroLine && !isFooterLine {
                    // This is the start of the actual message
                    foundMessage = true
                    messageLines.append(line)
                } else if foundMessage && !isFooterLine {
                    // Continue collecting message lines
                    messageLines.append(line)
                }
            }

            let cleaned = messageLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return (true, cleaned)
            }
        }

        // Check for old format with "💬 **Message for your partner:**"
        let oldMarker = "💬 **Message for your partner:**"
        if content.contains(oldMarker) {
            let lines = content.components(separatedBy: .newlines)
            var began = false
            var body: [String] = []
            for line in lines {
                if line.contains(oldMarker) { began = true; continue }
                if began {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("**") { continue }
                    if trimmed.localizedCaseInsensitiveContains("this message is ready") { break }
                    body.append(line)
                }
            }
            let cleaned = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (true, cleaned.isEmpty ? nil : cleaned)
        }

        return (false, nil)
    }
}
