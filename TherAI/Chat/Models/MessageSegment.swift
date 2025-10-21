import Foundation

enum MessageSegment: Identifiable, Equatable {
    case text(String)
    case partnerMessage(String)
    case partnerReceived(String)

    var id: String {
        switch self {
        case .text(let content):
            return "text_\(content.hashValue)"
        case .partnerMessage(let content):
            return "partner_\(content.hashValue)"
        case .partnerReceived(let content):
            return "partner_received_\(content.hashValue)"
        }
    }

    static func == (lhs: MessageSegment, rhs: MessageSegment) -> Bool {
        switch (lhs, rhs) {
        case (.text(let l), .text(let r)):
            return l == r
        case (.partnerMessage(let l), .partnerMessage(let r)):
            return l == r
        case (.partnerReceived(let l), .partnerReceived(let r)):
            return l == r
        default:
            return false
        }
    }
}

