import Foundation
import SwiftUI

struct SettingsData: Codable {

    var emailNotifications: Bool = true
    var pushNotifications: Bool = true
    var darkModeEnabled: Bool = false
    var hapticFeedbackEnabled: Bool = true
    var saveChatsEnabled: Bool = true
    var crashReportingEnabled: Bool = true

    init() {
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
    case linkPartner
}
