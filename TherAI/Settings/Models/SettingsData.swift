import Foundation
import SwiftUI

struct SettingsData: Codable {
    // App Settings
    var notificationsEnabled: Bool = true
    var darkModeEnabled: Bool = false
    var autoSaveEnabled: Bool = true
    var hapticFeedbackEnabled: Bool = true
    
    // Privacy Settings
    var dataCollectionEnabled: Bool = true
    var analyticsEnabled: Bool = true
    var crashReportingEnabled: Bool = true
    
    // Chat Settings
    var autoScrollEnabled: Bool = true
    var messageSoundEnabled: Bool = true
    var typingIndicatorEnabled: Bool = true
    
    // Account Settings
    var emailNotifications: Bool = true
    var pushNotifications: Bool = true
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
