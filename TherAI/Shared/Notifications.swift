import Foundation

extension Notification.Name {
    static let chatSessionCreated = Notification.Name("chat.session.created")
    static let chatMessageSent = Notification.Name("chat.message.sent")
    static let chatSessionsNeedRefresh = Notification.Name("chat.sessions.need.refresh")
    static let relationshipTotalsChanged = Notification.Name("relationship.totals.changed")
    static let avatarChanged = Notification.Name("avatar.changed")
    static let profileChanged = Notification.Name("profile.changed")
    static let partnerRequestOpen = Notification.Name("partner.request.open")
    static let partnerMessageOpen = Notification.Name("partner.message.open")
    static let partnerMessageReceived = Notification.Name("partner.message.received")
}


