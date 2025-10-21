import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let segments: [MessageSegment]
    let isFromUser: Bool
    let isFromPartnerUser: Bool
    let timestamp: Date
    let isToolLoading: Bool

    var partnerDrafts: [String] {
        return segments.compactMap { segment in
            if case .partnerMessage(let text) = segment { return text }
            return nil
        }
    }

    var partnerMessageContent: String? {
        if let draft = partnerDrafts.first { return draft }
        for segment in segments {
            if case .partnerReceived(let text) = segment { return text }
        }
        return nil
    }

    var isPartnerMessage: Bool {
        if !partnerDrafts.isEmpty { return true }
        return segments.contains { seg in
            if case .partnerReceived(_) = seg { return true }
            return false
        }
    }

    static func text(_ text: String, isFromUser: Bool, timestamp: Date = Date()) -> ChatMessage {
        return ChatMessage(
            segments: text.isEmpty ? [] : [.text(text)],
            isFromUser: isFromUser,
            isFromPartnerUser: false,
            timestamp: timestamp,
            isToolLoading: false
        )
    }

    init(id: UUID = UUID(), segments: [MessageSegment], isFromUser: Bool, isFromPartnerUser: Bool = false, timestamp: Date = Date(), isToolLoading: Bool = false) {
        self.id = id
        self.segments = segments
        self.isFromUser = isFromUser
        self.isFromPartnerUser = isFromPartnerUser
        self.timestamp = timestamp
        self.isToolLoading = isToolLoading
    }

    static func partnerReceived(_ text: String) -> ChatMessage {
        return ChatMessage(
            segments: [.partnerReceived(text)],
            isFromUser: false,
            isFromPartnerUser: false,
            timestamp: Date(),
            isToolLoading: false
        )
    }

    init(dto: ChatMessageDTO, currentUserId: UUID) {
        self.id = dto.id
        let isOwnUserRole = (dto.user_id == currentUserId) && dto.role == "user"
        self.isFromUser = isOwnUserRole
        self.isFromPartnerUser = (dto.user_id != currentUserId) && dto.role == "user"
        self.timestamp = Date()

        if let obj = ChatMessage.tryDecodeJSONDictionary(from: dto.content) {
            let therai = (obj["_therai"] as? [String: Any]) ?? ChatMessage.tryDecodeJSONDictionary(from: obj["_therai"]) ?? [:]
            let type = therai["type"] as? String
            if type == "segments" {
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
                        } else if t == "partner_received" {
                            let txt = (dict["text"] as? String) ?? ""
                            if !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                segs.append(.partnerReceived(txt))
                            }
                        }
                    }
                }
                self.segments = segs.isEmpty ? [.text("")] : segs
                self.isToolLoading = false
                return
            } else if type == "partner_received" {
                if let text = therai["text"] as? String {
                    let body = obj["body"] as? String ?? ""
                    var segs: [MessageSegment] = []
                    if !body.isEmpty {
                        segs.append(.text(body))
                    }
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        segs.append(.partnerReceived(text))
                    }
                    self.segments = segs.isEmpty ? [.text("")] : segs
                    self.isToolLoading = false
                    return
                }
            }
        }
        self.segments = dto.content.isEmpty ? [] : [.text(dto.content)]
        self.isToolLoading = false
    }

    private static func tryDecodeJSONDictionary(from value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] { return dict }
        if let str = value as? String, let data = str.data(using: .utf8) {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return dict
            }
        }
        return nil
    }
}
