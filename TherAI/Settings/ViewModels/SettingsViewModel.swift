import Foundation
import SwiftUI

enum SettingsDestination: Hashable {
    case link
    case appearance
    case avatar
}

extension SettingsDestination: Identifiable {
    var id: String {
        switch self {
        case .link:
            return "link"
        case .appearance:
            return "appearance"
        case .avatar:
            return "avatar"
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settingsData = SettingsData()
    @Published var settingsSections: [SettingsSection] = []
    @Published var destination: SettingsDestination? = nil
    @Published var showAppearanceDialog: Bool = false
    @Published var isUploadingAvatar: Bool = false
    @Published var avatarURL: String? = nil
    var currentAppearance: String {
        UserDefaults.standard.string(forKey: PreferenceKeys.appearancePreference) ?? "System"
    }

    init() {
        loadSettings()
        setupSettingsSections()
    }

    private func loadSettings() {
        // Load persisted preferences
        if UserDefaults.standard.object(forKey: PreferenceKeys.hapticsEnabled) != nil {
            settingsData.hapticFeedbackEnabled = UserDefaults.standard.bool(forKey: PreferenceKeys.hapticsEnabled)
        } else {
            // Default to enabled and persist initial value
            settingsData.hapticFeedbackEnabled = true
            UserDefaults.standard.set(true, forKey: PreferenceKeys.hapticsEnabled)
        }

        // Auto-scroll removed
    }

    private func setupSettingsSections() {
        let currentAppearance = self.currentAppearance
        settingsSections = [
            // 1. App Settings → Notifications, Appearance, Haptic Feedback
            SettingsSection(
                title: "App Settings",
                icon: "gear",
                gradient: [Color.blue, Color.purple],
                settings: [
                    SettingItem(title: "Notifications", subtitle: "Email and push notifications", type: .navigation, icon: "bell"),
                    SettingItem(title: "Appearance", subtitle: currentAppearance, type: .picker(["System", "Light", "Dark"]), icon: "paintpalette"),
                    SettingItem(title: "Haptic Feedback", subtitle: "Vibration feedback for interactions", type: .toggle(settingsData.hapticFeedbackEnabled), icon: "iphone.radiowaves.left.and.right")
                ]
            ),
            // 2. Chat Settings → Message Sound, Typing Indicator
            SettingsSection(
                title: "Chat Settings",
                icon: "message",
                gradient: [Color.green, Color.teal],
                settings: [
                    SettingItem(title: "Message Sound", subtitle: "Play sound for new messages", type: .toggle(settingsData.messageSoundEnabled), icon: "speaker.wave.2")
                ]
            ),
            // 3. Privacy & Data → Clear All Chat History
            SettingsSection(
                title: "Privacy & Data",
                icon: "lock.shield",
                gradient: [Color.orange, Color.red],
                settings: [
                    SettingItem(title: "Clear All Chat History", subtitle: "Also resets insights after refresh", type: .action, icon: "trash")
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
                    SettingItem(title: "Change Avatar", subtitle: "Upload a new profile photo", type: .action, icon: "person.crop.circle.badge.plus"),
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
        let section = settingsSections[sectionIndex]
        let setting = section.settings[settingIndex]

        switch (section.title, setting.title) {
        case ("App Settings", "Haptic Feedback"):
            settingsData.hapticFeedbackEnabled.toggle()
            UserDefaults.standard.set(settingsData.hapticFeedbackEnabled, forKey: PreferenceKeys.hapticsEnabled)
            if settingsData.hapticFeedbackEnabled {
                Haptics.selection()
            }
        case ("Chat Settings", "Auto Scroll"):
            break
        case ("Chat Settings", "Message Sound"):
            settingsData.messageSoundEnabled.toggle()

        default:
            break
        }

        // Rebuild sections to reflect UI changes
        setupSettingsSections()
    }

    func handleSettingAction(for sectionIndex: Int, settingIndex: Int) {
        let section = settingsSections[sectionIndex]
        let setting = section.settings[settingIndex]

        switch setting.title {
        case "Change Avatar":
            destination = .avatar
        case "Sign Out":
            Task {
                await AuthService.shared.signOut()
            }
        case "Link Your Partner":
            destination = .link
        case "Appearance":
            destination = .appearance
        case "Clear All Chat History":
            // Will clear conversations and reset insights in a later implementation
            break
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

    func selectAppearance(_ option: String) {
        UserDefaults.standard.set(option, forKey: PreferenceKeys.appearancePreference)
        showAppearanceDialog = false
        setupSettingsSections()
    }

    func handlePickerSelection(for sectionIndex: Int, settingIndex: Int, value: String) {
        let section = settingsSections[sectionIndex]
        let setting = section.settings[settingIndex]
        if section.title == "App Settings" && setting.title == "Appearance" {
            selectAppearance(value)
        }
    }
}

extension SettingsViewModel {
    func uploadAvatar(data: Data) async {
        guard !data.isEmpty else { return }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            guard let token = await AuthService.shared.getAccessToken() else { return }
            let result = try await BackendService.shared.uploadAvatar(imageData: data, contentType: "image/jpeg", accessToken: token)
            await MainActor.run {
                self.avatarURL = result.url
            }
        } catch {
            print("Avatar upload failed: \(error)")
        }
    }
}
