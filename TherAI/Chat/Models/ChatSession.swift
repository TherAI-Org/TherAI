import Foundation

struct ChatSession: Identifiable, Hashable, Equatable {
    let id: UUID
    let title: String?

    init(dto: ChatSessionDTO) {
        self.id = dto.id
        self.title = dto.title
    }

    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}