import Foundation

@MainActor
class PartnerDraftsViewModel: ObservableObject {

    @Published private(set) var sentPartnerDrafts: Set<String> = []

    private let globalSentDraftsKey = "globalSentPartnerDrafts"

    init() {
        loadSentDrafts()
    }

    func markPartnerDraftAsSent(sessionId: UUID?, messageContent: String) {
        guard let sessionId = sessionId else { return }
        let contentKey = String(messageContent.prefix(100))
        let key = "\(sessionId.uuidString)_\(contentKey)"
        sentPartnerDrafts.insert(key)
        UserDefaults.standard.set(Array(sentPartnerDrafts), forKey: globalSentDraftsKey)
    }

    func isPartnerDraftSent(sessionId: UUID?, messageContent: String) -> Bool {
        guard let sessionId = sessionId else { return false }
        let contentKey = String(messageContent.prefix(100))
        let key = "\(sessionId.uuidString)_\(contentKey)"
        return sentPartnerDrafts.contains(key)
    }

    private func loadSentDrafts() {
        if let savedDrafts = UserDefaults.standard.stringArray(forKey: globalSentDraftsKey) {
            sentPartnerDrafts = Set(savedDrafts)
        } else {
            sentPartnerDrafts = []
        }
    }
}


