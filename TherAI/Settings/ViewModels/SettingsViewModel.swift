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
    @Published var showAppearanceDialog: Bool = false
    @Published var isUploadingAvatar: Bool = false
    @Published var avatarURL: String? = nil
    @Published var isConnectedToPartner: Bool = false
    @Published var partnerName: String? = nil
    @Published var partnerAvatarURL: String? = nil
    @Published var showPersonalizationEdit: Bool = false
    @Published var isAvatarPreloaded: Bool = false
    
    private let avatarCacheManager = AvatarCacheManager.shared
    
    // Profile information
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var bio: String = ""
    @Published var isProfileLoaded: Bool = false
    var currentAppearance: String {
        UserDefaults.standard.string(forKey: PreferenceKeys.appearancePreference) ?? "System"
    }

    init() {
        loadSettings()
        setupSettingsSections()
        loadPartnerConnectionStatus()
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
            // 2. Link Your Partner → Separate section for partner linking
            SettingsSection(
                title: "Link Your Partner",
                icon: "link",
                gradient: [Color.pink, Color.purple],
                settings: [
                    SettingItem(title: "Link Your Partner", subtitle: "Invite or manage link", type: .linkPartner, icon: "link")
                ]
            ),
            // 3. Help & Support → Support and policies
            SettingsSection(
                title: "Help & Support",
                icon: "questionmark.circle",
                gradient: [Color.green, Color.blue],
                settings: [
                    SettingItem(title: "Contact Support", subtitle: "Get help with your account", type: .navigation, icon: "envelope"),
                    SettingItem(title: "Privacy Policy", subtitle: "How we protect your data", type: .navigation, icon: "hand.raised")
                ]
            ),
            // 4. Account → Sign out
            SettingsSection(
                title: "Account",
                icon: "person.circle",
                gradient: [Color.red, Color.orange],
                settings: [
                    SettingItem(title: "Sign Out", subtitle: "Sign out of your account", type: .action, icon: "rectangle.portrait.and.arrow.right")
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
        // Message Sound setting removed

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
        case "Link Your Partner":
            destination = .link
        case "Notifications":
            // Navigate to notifications detail view
            break
        case "Contact Support":
            // Open support contact
            if let url = URL(string: "mailto:support@therai.app") {
                UIApplication.shared.open(url)
            }
        case "Privacy Policy":
            // Open privacy policy
            if let url = URL(string: "https://therai.app/privacy") {
                UIApplication.shared.open(url)
            }
        case "Sign Out":
            // Sign out user
            Task {
                await AuthService.shared.signOut()
            }
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
    
    // Load partner connection status from backend
    private func loadPartnerConnectionStatus() {
        Task { @MainActor in
            do {
                guard let token = await AuthService.shared.getAccessToken() else {
                    self.isConnectedToPartner = false
                    self.partnerName = nil
                    self.partnerAvatarURL = nil
                    return
                }
                let partnerInfo = try await BackendService.shared.fetchPartnerInfo(accessToken: token)
                self.isConnectedToPartner = partnerInfo.linked
                
                if partnerInfo.linked, let partner = partnerInfo.partner {
                    self.partnerName = partner.name
                    self.partnerAvatarURL = partner.avatar_url
                } else {
                    self.partnerName = nil
                    self.partnerAvatarURL = nil
                }
            } catch {
                print("Failed to load partner connection status: \(error)")
                self.isConnectedToPartner = false
                self.partnerName = nil
                self.partnerAvatarURL = nil
            }
        }
    }
    
    func preloadAvatar() {
        Task { @MainActor in
            // Use the cache manager to preload avatar
            if let avatarURL = avatarURL, !avatarURL.isEmpty {
                let _ = await avatarCacheManager.getCachedImage(urlString: avatarURL)
                self.isAvatarPreloaded = true
            } else {
                self.isAvatarPreloaded = true // No avatar to preload
            }
        }
    }
    
    /// Get cached avatar image
    func getCachedAvatar(urlString: String?) async -> UIImage? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        return await avatarCacheManager.getCachedImage(urlString: urlString)
    }
    
    func loadProfileInfo() {
        Task { @MainActor in
            do {
                guard let token = await AuthService.shared.getAccessToken() else {
                    self.isProfileLoaded = false
                    return
                }
                let profileInfo = try await BackendService.shared.fetchProfileInfo(accessToken: token)
                self.firstName = profileInfo.first_name
                self.lastName = profileInfo.last_name
                self.bio = profileInfo.bio
                self.isProfileLoaded = true
            } catch {
                print("Failed to load profile info: \(error)")
                self.isProfileLoaded = false
            }
        }
    }
    
    func saveProfileInfo(firstName: String, lastName: String, bio: String) async -> Bool {
        do {
            guard let token = await AuthService.shared.getAccessToken() else {
                return false
            }
            let response = try await BackendService.shared.updateProfile(
                accessToken: token,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                bio: bio.isEmpty ? nil : bio
            )
            return response.success
        } catch {
            print("Failed to save profile info: \(error)")
            return false
        }
    }
    
    // Public method to refresh connection status
    func refreshConnectionStatus() {
        loadPartnerConnectionStatus()
    }
}

extension SettingsViewModel {
    func uploadAvatar(data: Data) async {
        print("DEBUG: ❗️ uploadAvatar called with data size: \(data.count) bytes")
        print("DEBUG: ❗️ Stack trace:")
        Thread.callStackSymbols.forEach { print("  \($0)") }
        guard !data.isEmpty else {
            print("DEBUG: ❗️ Data is empty, returning")
            return
        }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            guard let token = await AuthService.shared.getAccessToken() else {
                print("DEBUG: ❗️ No access token, returning")
                return
            }
            print("DEBUG: ❗️ About to call BackendService.uploadAvatar")
            let result = try await BackendService.shared.uploadAvatar(imageData: data, contentType: "image/jpeg", accessToken: token)
            await MainActor.run {
                self.avatarURL = result.url
                print("DEBUG: ❗️ Avatar uploaded successfully. URL: \(String(describing: result.url))")
            }
        } catch {
            print("DEBUG: ❗️ Avatar upload failed: \(error)")
        }
    }
}

