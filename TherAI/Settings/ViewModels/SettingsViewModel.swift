import Foundation
import SwiftUI

enum SettingsDestination: Hashable {
    case link
    case contactSupport
    case privacyPolicy
}

extension SettingsDestination: Identifiable {
    var id: String {
        switch self {
        case .link:
            return "link"
        case .contactSupport:
            return "contactSupport"
        case .privacyPolicy:
            return "privacyPolicy"
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
    @Published var fullName: String = ""
    @Published var bio: String = ""
    @Published var isProfileLoaded: Bool = false
    // Appearance selection removed; app follows system

    init() {
        loadSettings()
        setupSettingsSections()
        loadCachedPartnerConnection()
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
        settingsSections = [
            // 1. App Settings → Notifications, Haptic Feedback
            SettingsSection(
                title: "App Settings",
                icon: "gear",
                gradient: [Color.blue, Color.purple],
                settings: [
                    SettingItem(title: "Notifications", subtitle: nil, type: .toggle(PushNotificationManager.shared.isPushEnabled), icon: "bell"),
                    SettingItem(title: "Haptics", subtitle: nil, type: .toggle(settingsData.hapticFeedbackEnabled), icon: "iphone.radiowaves.left.and.right")
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
                    SettingItem(title: "Contact Support", subtitle: nil, type: .navigation, icon: "envelope"),
                    SettingItem(title: "Privacy Policy", subtitle: nil, type: .navigation, icon: "hand.raised")
                ]
            ),
            // 4. Account → Sign out
            SettingsSection(
                title: "Account",
                icon: "person.circle",
                gradient: [Color.red, Color.orange],
                settings: [
                    SettingItem(title: "Sign Out", subtitle: nil, type: .action, icon: "rectangle.portrait.and.arrow.right")
                ]
            )
        ]
    }

    func toggleSetting(for sectionIndex: Int, settingIndex: Int) {
        let section = settingsSections[sectionIndex]
        let setting = section.settings[settingIndex]

        switch (section.title, setting.title) {
        case ("App Settings", "Haptic Feedback"), ("App Settings", "Haptics"):
            settingsData.hapticFeedbackEnabled.toggle()
            UserDefaults.standard.set(settingsData.hapticFeedbackEnabled, forKey: PreferenceKeys.hapticsEnabled)
            if settingsData.hapticFeedbackEnabled {
                Haptics.selection()
            }
        case ("App Settings", "Push Notifications"), ("App Settings", "Notifications"):
            let current = UserDefaults.standard.object(forKey: "therai_push_enabled") != nil ?
                UserDefaults.standard.bool(forKey: "therai_push_enabled") : true
            let newValue = !current
            PushNotificationManager.shared.setPushEnabled(newValue)
            // ensure UI reflects latest value
            DispatchQueue.main.async { self.setupSettingsSections() }
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
            // Inline toggle only; no navigation
            break
        case "Contact Support":
            destination = .contactSupport
        case "Privacy Policy":
            destination = .privacyPolicy
        case "Sign Out":
            Task {
                // Sign out immediately - this will trigger auth state change
                await AuthService.shared.signOut()
                await MainActor.run {
                    self.isConnectedToPartner = false
                    self.partnerName = nil
                    self.partnerAvatarURL = nil
                    self.clearPartnerConnectionCache()
                }
            }
        default:
            // Handle other navigation and action items
            break
        }
    }

    func handlePickerSelection(for sectionIndex: Int, settingIndex: Int, value: String) {
        // No pickers in current settings
    }

    // Load partner connection status from backend
    private func loadPartnerConnectionStatus() {
        Task { @MainActor in
            do {
                guard let token = await AuthService.shared.getAccessToken() else {
                    // Keep cached state if token is unavailable
                    return
                }
                let partnerInfo = try await BackendService.shared.fetchPartnerInfo(accessToken: token)
                self.isConnectedToPartner = partnerInfo.linked

                if partnerInfo.linked, let partner = partnerInfo.partner {
                    self.partnerName = partner.name
                    self.partnerAvatarURL = partner.avatar_url
                    self.savePartnerConnectionCache()
                    // Preload partner avatar into cache for instant display
                    if let url = self.partnerAvatarURL, !url.isEmpty {
                        Task { [weak self] in
                            guard let self = self else { return }
                            _ = await self.avatarCacheManager.getCachedImage(urlString: url)
                        }
                    }
                } else {
                    self.isConnectedToPartner = false
                    self.partnerName = nil
                    self.partnerAvatarURL = nil
                    self.clearPartnerConnectionCache()
                }
            } catch {
                print("Failed to load partner connection status: \(error)")
                // Preserve cached UI on error
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
                self.fullName = profileInfo.full_name
                self.bio = profileInfo.bio
                self.isProfileLoaded = true
                // Persist display name for use in sidebar and other views
                UserDefaults.standard.set(self.fullName, forKey: "therai_profile_full_name")
            } catch {
                print("Failed to load profile info: \(error)")
                self.isProfileLoaded = false
            }
        }
    }

    func saveProfileInfo(fullName: String, bio: String) async -> Bool {
        do {
            guard let token = await AuthService.shared.getAccessToken() else {
                return false
            }
            let response = try await BackendService.shared.updateProfile(
                accessToken: token,
                fullName: fullName.isEmpty ? nil : fullName,
                bio: bio.isEmpty ? nil : bio
            )
            if response.success {
                await MainActor.run {
                    self.fullName = fullName
                    self.bio = bio
                    self.isProfileLoaded = true
                    UserDefaults.standard.set(self.fullName, forKey: "therai_profile_full_name")
                    NotificationCenter.default.post(name: .profileChanged, object: nil)
                }
            }
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

    // Cached partner connection
    private func loadCachedPartnerConnection() {
        if UserDefaults.standard.object(forKey: PreferenceKeys.partnerConnected) != nil {
            let connected = UserDefaults.standard.bool(forKey: PreferenceKeys.partnerConnected)
            self.isConnectedToPartner = connected
            if connected {
                self.partnerName = UserDefaults.standard.string(forKey: PreferenceKeys.partnerName)
                self.partnerAvatarURL = UserDefaults.standard.string(forKey: PreferenceKeys.partnerAvatarURL)
                // Warm partner avatar cache on app/settings open
                if let url = self.partnerAvatarURL, !url.isEmpty {
                    Task { [weak self] in
                        guard let self = self else { return }
                        _ = await self.avatarCacheManager.getCachedImage(urlString: url)
                    }
                }
            } else {
                self.partnerName = nil
                self.partnerAvatarURL = nil
            }
        }
    }

    private func savePartnerConnectionCache() {
        UserDefaults.standard.set(self.isConnectedToPartner, forKey: PreferenceKeys.partnerConnected)
        if self.isConnectedToPartner {
            if let name = self.partnerName {
                UserDefaults.standard.set(name, forKey: PreferenceKeys.partnerName)
            }
            if let avatar = self.partnerAvatarURL {
                UserDefaults.standard.set(avatar, forKey: PreferenceKeys.partnerAvatarURL)
            }
        }
    }

    private func clearPartnerConnectionCache() {
        UserDefaults.standard.set(false, forKey: PreferenceKeys.partnerConnected)
        UserDefaults.standard.removeObject(forKey: PreferenceKeys.partnerName)
        UserDefaults.standard.removeObject(forKey: PreferenceKeys.partnerAvatarURL)
    }

    // Public: preload using currently known cached URL
    func preloadPartnerAvatarIfAvailable() {
        Task { @MainActor in
            if let url = self.partnerAvatarURL, !url.isEmpty {
                _ = await self.avatarCacheManager.getCachedImage(urlString: url)
            }
        }
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

