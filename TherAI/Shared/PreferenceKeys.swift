import Foundation

enum PreferenceKeys {
    static let appearancePreference = "appearance_preference"
    static let hapticsEnabled = "haptics_enabled"
    static let autoScrollEnabled = "auto_scroll_enabled"
}

extension Notification.Name {
    static let scrollToBottom = Notification.Name("scrollToBottom")
}
