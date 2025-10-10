import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String  // Keep for backward compatibility
    let segments: [MessageSegment]  // New: segmented content
    let isFromUser: Bool
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
            timestamp: Date(),
            isPartnerMessage: true,
            partnerMessageContent: text,
            partnerDrafts: [text],
            isToolLoading: false
        )
    }

    // Explicit initializer to construct a message with partner flags and segments
    init(id: UUID = UUID(), content: String, segments: [MessageSegment]? = nil, isFromUser: Bool, timestamp: Date = Date(), isPartnerMessage: Bool, partnerMessageContent: String?, partnerDrafts: [String] = [], isToolLoading: Bool = false) {
        self.id = id
        self.content = content
        self.segments = segments ?? [.text(content)]
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.isPartnerMessage = isPartnerMessage
        self.partnerMessageContent = partnerMessageContent
        self.partnerDrafts = partnerDrafts
        self.isToolLoading = isToolLoading
    }

    // Initializes a chat message from a backend DTO
    init(dto: ChatMessageDTO, currentUserId: UUID) {
        self.id = dto.id
        self.isFromUser = (dto.user_id == currentUserId) && dto.role == "user"
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
        self.content = dto.content
        self.segments = [.text(dto.content)]
        let parsed = Self.parsePartnerMessage(dto.content)
        self.isPartnerMessage = parsed.isPartner
        self.partnerMessageContent = parsed.content
        self.partnerDrafts = parsed.content.map { [$0] } ?? []
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
        return (false, nil)
    }
}
