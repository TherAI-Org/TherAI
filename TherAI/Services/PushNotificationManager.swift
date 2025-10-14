import Foundation
import UserNotifications
import UIKit

final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var authorizationGranted: Bool = false
    private(set) var currentDeviceToken: String?
    @Published var isPushEnabled: Bool = true
    // If a notification tap arrives before the user is authenticated, stash the request id
    var pendingRequestId: UUID?
    // Coalesce multiple system callbacks for the same request id
    private var processingRequestIds: Set<UUID> = []

    private override init() {
        super.init()
        // Ensure delegate is always set on main thread
        if Thread.isMainThread {
            UNUserNotificationCenter.current().delegate = self
        } else {
            DispatchQueue.main.async { UNUserNotificationCenter.current().delegate = self }
        }
    }

    func requestAuthorizationAndRegister() {
        if Thread.isMainThread {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorizationGranted = granted
                    if granted, self?.isPushEnabled ?? true {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in self?.requestAuthorizationAndRegister() }
        }
    }

    func didReceiveDeviceToken(_ token: String) {
        currentDeviceToken = token
        print("[Push] Device token (hex)=\(token)")
        Task { await registerTokenWithBackendIfPossible(token) }
    }

    func tryUploadIfAuthenticated() {
        guard let token = currentDeviceToken else { return }
        Task { await registerTokenWithBackendIfPossible(token) }
    }

    private func registerTokenWithBackendIfPossible(_ token: String) async {
        do {
            let session = try await AuthService.shared.client.auth.session
            let accessToken = session.accessToken
            guard isPushEnabled else { return }
            try await BackendService.shared.registerPushToken(
                token: token,
                platform: "ios",
                bundleId: Bundle.main.bundleIdentifier ?? "",
                accessToken: accessToken
            )
        } catch {
            // Silent: user might not be signed in yet; we'll retry on auth change
        }
    }

    // MARK: - Enable/Disable Push
    func setPushEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.isPushEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "therai_push_enabled")
        }
        if enabled {
            // Re-register if authorized
            if authorizationGranted {
                UIApplication.shared.registerForRemoteNotifications()
                tryUploadIfAuthenticated()
            } else {
                requestAuthorizationAndRegister()
            }
        } else {
            // Unregister with backend if we have a token
            if let token = currentDeviceToken {
                Task {
                    do {
                        let session = try await AuthService.shared.client.auth.session
                        let accessToken = session.accessToken
                        try await BackendService.shared.unregisterPushToken(token: token, accessToken: accessToken)
                    } catch { }
                }
            }
            DispatchQueue.main.async { UIApplication.shared.unregisterForRemoteNotifications() }
        }
    }

    func loadPushEnabledFromDefaults() {
        if UserDefaults.standard.object(forKey: "therai_push_enabled") != nil {
            isPushEnabled = UserDefaults.standard.bool(forKey: "therai_push_enabled")
        } else {
            isPushEnabled = true
            UserDefaults.standard.set(true, forKey: "therai_push_enabled")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Include .list so notifications also land in Notification Center when app is foreground
        // If this is a partner message, emit a received event so UI can badge the session
        let userInfo = notification.request.content.userInfo
        print("[Push] willPresent notification with userInfo: \(userInfo)")
        if let sessionIdString = userInfo["session_id"] as? String,
           let sessionId = UUID(uuidString: sessionIdString) {
            print("[Push] Partner message for session \(sessionId), authenticated=\(AuthService.shared.isAuthenticated)")
            // Only post if linked; otherwise ignore
            if AuthService.shared.isAuthenticated {
                // We do not have direct access to ChatSessionsViewModel here; gate by auth only
                print("[Push] Posting partnerMessageReceived notification for session \(sessionId)")
                NotificationCenter.default.post(name: .partnerMessageReceived, object: nil, userInfo: ["sessionId": sessionId])
            }
        }
        return [.banner, .list, .sound, .badge]
    }

    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        // Partner request push
        if let requestIdString = userInfo["request_id"] as? String,
           let requestId = UUID(uuidString: requestIdString) {
            // If authenticated, route immediately; otherwise store to handle after login
            if AuthService.shared.isAuthenticated {
                // Clear any pending request to avoid duplicate processing
                if pendingRequestId == requestId {
                    pendingRequestId = nil
                }
                // Post immediately using deduplication
                guard processingRequestIds.insert(requestId).inserted else { return }
                NotificationCenter.default.post(name: .partnerRequestOpen, object: nil, userInfo: ["requestId": requestId])
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.processingRequestIds.remove(requestId) }
            } else {
                // Not authenticated: stash to be handled once login/activation occurs
                pendingRequestId = requestId
            }
            return
        }

        // Partner message push: open the session directly (no need to mark unread since user is viewing it)
        if let sessionIdString = userInfo["session_id"] as? String,
           let sessionId = UUID(uuidString: sessionIdString) {
            if AuthService.shared.isAuthenticated {
                NotificationCenter.default.post(name: .partnerMessageOpen, object: nil, userInfo: ["sessionId": sessionId])
            } else {
                // If not authenticated yet, delay handling slightly until app attaches auth state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if AuthService.shared.isAuthenticated {
                        NotificationCenter.default.post(name: .partnerMessageOpen, object: nil, userInfo: ["sessionId": sessionId])
                    }
                }
            }
            return
        }
    }

    @MainActor
    func consumePendingIfReady() {
        // Only process pending request if authenticated and not already processing
        guard let req = pendingRequestId, AuthService.shared.isAuthenticated else { return }
        // Check if already processing to avoid duplicates
        guard processingRequestIds.insert(req).inserted else {
            // Already processing, clear the pending
            pendingRequestId = nil
            return
        }
        pendingRequestId = nil
        NotificationCenter.default.post(name: .partnerRequestOpen, object: nil, userInfo: ["requestId": req])
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.processingRequestIds.remove(req) }
    }
}


