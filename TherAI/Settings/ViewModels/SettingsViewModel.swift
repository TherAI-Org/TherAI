import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settingsData = SettingsData()
    @Published var settingsSections: [SettingsSection] = []
    
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
            SettingsSection(
                title: "App Settings",
                icon: "gear",
                gradient: [Color.blue, Color.purple],
                settings: [
                    SettingItem(title: "Notifications", subtitle: "Push notifications for new messages", type: .toggle(settingsData.notificationsEnabled), icon: "bell"),
                    SettingItem(title: "Dark Mode", subtitle: "Use dark appearance", type: .toggle(settingsData.darkModeEnabled), icon: "moon"),
                    SettingItem(title: "Haptic Feedback", subtitle: "Vibration feedback for interactions", type: .toggle(settingsData.hapticFeedbackEnabled), icon: "iphone.radiowaves.left.and.right"),
                    SettingItem(title: "Auto Save", subtitle: "Automatically save conversations", type: .toggle(settingsData.autoSaveEnabled), icon: "square.and.arrow.down")
                ]
            ),
            SettingsSection(
                title: "Chat Settings",
                icon: "message",
                gradient: [Color.green, Color.teal],
                settings: [
                    SettingItem(title: "Auto Scroll", subtitle: "Automatically scroll to new messages", type: .toggle(settingsData.autoScrollEnabled), icon: "arrow.down.circle"),
                    SettingItem(title: "Message Sound", subtitle: "Play sound for new messages", type: .toggle(settingsData.messageSoundEnabled), icon: "speaker.wave.2"),
                    SettingItem(title: "Typing Indicator", subtitle: "Show when partner is typing", type: .toggle(settingsData.typingIndicatorEnabled), icon: "ellipsis.bubble")
                ]
            ),
            SettingsSection(
                title: "Privacy & Data",
                icon: "lock.shield",
                gradient: [Color.orange, Color.red],
                settings: [
                    SettingItem(title: "Data Collection", subtitle: "Help improve TherAI with usage data", type: .toggle(settingsData.dataCollectionEnabled), icon: "chart.bar"),
                    SettingItem(title: "Analytics", subtitle: "Share analytics data", type: .toggle(settingsData.analyticsEnabled), icon: "chart.line.uptrend.xyaxis"),
                    SettingItem(title: "Crash Reports", subtitle: "Automatically send crash reports", type: .toggle(settingsData.crashReportingEnabled), icon: "exclamationmark.triangle")
                ]
            ),
            SettingsSection(
                title: "Account",
                icon: "person.circle",
                gradient: [Color.pink, Color.purple],
                settings: [
                    SettingItem(title: "Email Notifications", subtitle: "Receive updates via email", type: .toggle(settingsData.emailNotifications), icon: "envelope"),
                    SettingItem(title: "Push Notifications", subtitle: "Receive push notifications", type: .toggle(settingsData.pushNotifications), icon: "bell.badge"),
                    SettingItem(title: "Weekly Reports", subtitle: "Get weekly relationship insights", type: .toggle(settingsData.weeklyReports), icon: "calendar"),
                    SettingItem(title: "Account Settings", subtitle: "Manage your account", type: .navigation, icon: "person.crop.circle"),
                    SettingItem(title: "Sign Out", subtitle: "Sign out of your account", type: .action, icon: "rectangle.portrait.and.arrow.right")
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
        default:
            // Handle other navigation and action items
            break
        }
    }
}
