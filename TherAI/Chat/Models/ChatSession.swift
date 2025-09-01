import Foundation

struct ChatSession: Identifiable, Hashable {
    let id: UUID
    let title: String?

    init(dto: ChatSessionDTO) {
        self.id = dto.id
        self.title = dto.title
    }
}