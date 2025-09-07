import Foundation
import SwiftUI

enum SettingsDestination: Hashable {
    case link
}

extension SettingsDestination: Identifiable {
    var id: String {
        switch self {
        case .link:
            return "link"
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settingsData = SettingsData()
    @Published var settingsSections: [SettingsSection] = []
    @Published var destination: SettingsDestination? = nil

    init() {
        loadSettings()
        setupSettingsSections()
    }

    private func loadSettings() {
        // Load settings from UserDefaults or other storage
        // For now, using default values
    }

    private func setupSettingsSections() {
        settingsSections = [
            // 1. App Settings → Notifications, Dark Mode, Haptic Feedback
            SettingsSection(
                title: "App Settings",
                icon: "gear",
                gradient: [Color.blue, Color.purple],
                settings: [
                    SettingItem(title: "Notifications", subtitle: "Email and push notifications", type: .navigation, icon: "bell"),
                    SettingItem(title: "Dark Mode", subtitle: "Use dark appearance", type: .toggle(settingsData.darkModeEnabled), icon: "moon"),
                    SettingItem(title: "Haptic Feedback", subtitle: "Vibration feedback for interactions", type: .toggle(settingsData.hapticFeedbackEnabled), icon: "iphone.radiowaves.left.and.right")
                ]
            ),
            // 2. Chat Settings → Save Chats, Auto Scroll, Message Sound, Typing Indicator
            SettingsSection(
                title: "Chat Settings",
                icon: "message",
                gradient: [Color.green, Color.teal],
                settings: [
                    SettingItem(title: "Save Chats", subtitle: "Automatically save conversations", type: .toggle(settingsData.saveChatsEnabled), icon: "square.and.arrow.down"),
                    SettingItem(title: "Auto Scroll", subtitle: "Automatically scroll to new messages", type: .toggle(settingsData.autoScrollEnabled), icon: "arrow.down.circle"),
                    SettingItem(title: "Message Sound", subtitle: "Play sound for new messages", type: .toggle(settingsData.messageSoundEnabled), icon: "speaker.wave.2"),
                    SettingItem(title: "Typing Indicator", subtitle: "Show when partner is typing", type: .toggle(settingsData.typingIndicatorEnabled), icon: "ellipsis.bubble")
                ]
            ),
            // 3. Privacy & Data → Crash Reports
            SettingsSection(
                title: "Privacy & Data",
                icon: "lock.shield",
                gradient: [Color.orange, Color.red],
                settings: [
                    SettingItem(title: "Crash Reports", subtitle: "Automatically send crash reports", type: .toggle(settingsData.crashReportingEnabled), icon: "exclamationmark.triangle")
                ]
            ),
            // 4. Relationship Insights → Weekly Reports
            SettingsSection(
                title: "Relationship Insights",
                icon: "heart.text.square",
                gradient: [Color.pink, Color.purple],
                settings: [
                    SettingItem(title: "Link Your Partner", subtitle: "Invite or manage link", type: .navigation, icon: "link"),
                    SettingItem(title: "Weekly Reports", subtitle: "Get weekly relationship insights", type: .toggle(settingsData.weeklyReports), icon: "calendar")
                ]
            ),
            // 5. Account → Account Settings, Sign Out
            SettingsSection(
                title: "Account",
                icon: "person.circle",
                gradient: [Color.indigo, Color.blue],
                settings: [
                    SettingItem(title: "Account Settings", subtitle: "Manage your account", type: .navigation, icon: "person.crop.circle"),
                    SettingItem(title: "Sign Out", subtitle: "Sign out of your account", type: .action, icon: "rectangle.portrait.and.arrow.right")
                ]
            ),
            // 6. About → Version, Help & Support
            SettingsSection(
                title: "About",
                icon: "info.circle",
                gradient: [Color.gray, Color.secondary],
                settings: [
                    SettingItem(title: "Version", subtitle: "1.0.0", type: .navigation, icon: "info.circle"),
                    SettingItem(title: "Help & Support", subtitle: "Get help and contact support", type: .navigation, icon: "questionmark.circle")
                ]
            )
        ]
    }

    func toggleSetting(for sectionIndex: Int, settingIndex: Int) {
        // Handle toggle actions
        // This would update the actual settings and save them
    }

    func handleSettingAction(for sectionIndex: Int, settingIndex: Int) {
        let section = settingsSections[sectionIndex]
        let setting = section.settings[settingIndex]

        switch setting.title {
        case "Sign Out":
            Task {
                await AuthService.shared.signOut()
            }
        case "Link Your Partner":
            destination = .link
        case "Notifications":
            // Navigate to notifications detail view
            break
        case "Account Settings":
            // Navigate to account settings
            break
        case "Version":
            // Show app version info
            break
        case "Help & Support":
            // Navigate to help & support
            break
        default:
            // Handle other navigation and action items
            break
        }
    }
}
