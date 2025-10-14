import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String  // Keep for backward compatibility
    let segments: [MessageSegment]  // New: segmented content
    let isFromUser: Bool
    let isFromPartnerUser: Bool
    let timestamp: Date
    let isPartnerMessage: Bool
    let partnerMessageContent: String?
    let partnerDrafts: [String]
    let isToolLoading: Bool

    // Initializes a chat message locally
    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.segments = [.text(content)]  // Simple text segment
        self.isFromUser = isFromUser
        self.isFromPartnerUser = false
        self.timestamp = timestamp
        let parsed = Self.parsePartnerMessage(content)
        self.isPartnerMessage = parsed.isPartner
        self.partnerMessageContent = parsed.content
        self.partnerDrafts = []
        self.isToolLoading = false
    }

    // Initializes a partner message coming from SSE event
    static func partnerDraft(_ text: String) -> ChatMessage {
        // Render partner draft within assistant bubble and explicitly mark as partner message
        return ChatMessage(
            id: UUID(),
            content: text,
            segments: [.partnerMessage(text)],
            isFromUser: false,
            isFromPartnerUser: false,
            timestamp: Date(),
            isPartnerMessage: true,
            partnerMessageContent: text,
            partnerDrafts: [text],
            isToolLoading: false
        )
    }

    // Explicit initializer to construct a message with partner flags and segments
    init(id: UUID = UUID(), content: String, segments: [MessageSegment]? = nil, isFromUser: Bool, isFromPartnerUser: Bool = false, timestamp: Date = Date(), isPartnerMessage: Bool, partnerMessageContent: String?, partnerDrafts: [String] = [], isToolLoading: Bool = false) {
        self.id = id
        self.content = content
        self.segments = segments ?? [.text(content)]
        self.isFromUser = isFromUser
        self.isFromPartnerUser = isFromPartnerUser
        self.timestamp = timestamp
        self.isPartnerMessage = isPartnerMessage
        self.partnerMessageContent = partnerMessageContent
        self.partnerDrafts = partnerDrafts
        self.isToolLoading = isToolLoading
    }

    // Initializes a chat message from a backend DTO
    init(dto: ChatMessageDTO, currentUserId: UUID) {
        self.id = dto.id
        let isOwnUserRole = (dto.user_id == currentUserId) && dto.role == "user"
        self.isFromUser = isOwnUserRole
        self.isFromPartnerUser = (dto.user_id != currentUserId) && dto.role == "user"
        self.timestamp = Date()

        // Try to parse structured annotations. Handle both direct JSON and double-encoded JSON strings.
        if let obj = ChatMessage.tryDecodeJSONDictionary(from: dto.content) {
            let therai = (obj["_therai"] as? [String: Any]) ?? ChatMessage.tryDecodeJSONDictionary(from: obj["_therai"]) ?? [:]
            let type = therai["type"] as? String
            if type == "segments" {
                // Ordered segments persistence
                let segmentsArr = (therai["segments"] as? [Any]) ?? (obj["segments"] as? [Any]) ?? []
                var segs: [MessageSegment] = []
                var partnerTexts: [String] = []
                for item in segmentsArr {
                    if let dict = item as? [String: Any], let t = dict["type"] as? String {
                        if t == "text" {
                            let c = (dict["content"] as? String) ?? ""
                            if !c.isEmpty { segs.append(.text(c)) }
                        } else if t == "partner_draft" {
                            let txt = (dict["text"] as? String) ?? ""
                            if !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                segs.append(.partnerMessage(txt))
                                partnerTexts.append(txt)
                            }
                        }
                    }
                }
                self.content = segs.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
                self.segments = segs.isEmpty ? [.text("")] : segs
                self.partnerDrafts = partnerTexts
                self.isPartnerMessage = !partnerTexts.isEmpty
                self.partnerMessageContent = partnerTexts.first
                self.isToolLoading = false
                return
            } else if type == "partner_draft" {
                // Backward compatibility: single draft annotation; no body
                if let text = therai["text"] as? String {
                    let body = obj["body"] as? String ?? ""
                    self.content = body
                    var segs: [MessageSegment] = []
                    if !body.isEmpty {
                        segs.append(.text(body))
                    }
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        segs.append(.partnerMessage(text))
                    }
                    self.segments = segs.isEmpty ? [.text("")] : segs
                    self.partnerDrafts = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [text]
                    self.isPartnerMessage = !self.partnerDrafts.isEmpty
                    self.partnerMessageContent = self.partnerDrafts.first
                    self.isToolLoading = false
                    return
                }
            }
        }

        // Default path: plain text content
        // Handle legacy <partner_message>...</partner_message> tags to populate segments
        let legacy = Self.extractPartnerTagsAndBody(from: dto.content)
        self.content = legacy.body
        var segs: [MessageSegment] = []
        if !legacy.body.isEmpty { segs.append(.text(legacy.body)) }
        if let first = legacy.drafts.first { segs.append(.partnerMessage(first)) }
        self.segments = segs.isEmpty ? [.text(dto.content)] : segs
        self.isPartnerMessage = !legacy.drafts.isEmpty
        self.partnerMessageContent = legacy.drafts.first
        self.partnerDrafts = legacy.drafts
        self.isToolLoading = false
    }

    // Liberal JSON dictionary decoding: accepts a dictionary or a JSON string containing one
    private static func tryDecodeJSONDictionary(from value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] { return dict }
        if let str = value as? String, let data = str.data(using: .utf8) {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return dict
            }
        }
        return nil
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
        // Legacy tag format: <partner_message>...</partner_message>
        let legacy = extractPartnerTagsAndBody(from: content)
        if let first = legacy.drafts.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (true, first)
        }
        return (false, nil)
    }

    // Extracts partner message(s) from legacy tag markup and returns body without tags
    private static func extractPartnerTagsAndBody(from content: String) -> (body: String, drafts: [String]) {
        let openTag = "<partner_message>"
        let closeTag = "</partner_message>"
        var drafts: [String] = []
        var remaining = content
        while let openRange = remaining.range(of: openTag), let closeRange = remaining.range(of: closeTag, range: openRange.upperBound..<remaining.endIndex) {
            let draft = String(remaining[openRange.upperBound..<closeRange.lowerBound])
            drafts.append(draft.trimmingCharacters(in: .whitespacesAndNewlines))
            remaining.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
        }
        let body = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, drafts)
    }
}
