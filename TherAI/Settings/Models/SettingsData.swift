import Foundation
import SwiftUI

struct SettingsData: Codable {
    // App Settings - Notifications, Dark Mode, Haptic Feedback
    var emailNotifications: Bool = true
    var pushNotifications: Bool = true
    var darkModeEnabled: Bool = false
    var hapticFeedbackEnabled: Bool = true
    
    // Chat Settings - Save Chats, Auto Scroll, Message Sound, Typing Indicator
    var saveChatsEnabled: Bool = true
    var autoScrollEnabled: Bool = true
    var messageSoundEnabled: Bool = true
    var typingIndicatorEnabled: Bool = true
    
    // Privacy & Data - Crash Reports only
    var crashReportingEnabled: Bool = true
    
    // Relationship Insights - Weekly Reports
    var weeklyReports: Bool = true
    
    init() {
        // Default settings
    }
}

struct SettingsSection {
    let title: String
    let icon: String
    let gradient: [Color]
    let settings: [SettingItem]
}

struct SettingItem {
    let title: String
    let subtitle: String?
    let type: SettingType
    let icon: String
}

enum SettingType {
    case toggle(Bool)
    case navigation
    case action
    case picker([String])
}
