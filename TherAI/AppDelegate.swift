import Foundation
import UIKit
import UserNotifications

// AppDelegate to handle push notification callbacks
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Ensure notification delegate is set as early as possible so taps from terminated state are delivered
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
        // If app was launched by tapping a notification, capture its payload
        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let reqString = remote["request_id"] as? String,
           let reqId = UUID(uuidString: reqString) {
            // Only stash for later if not already authenticated
            // When authenticated, the notification will be handled by the delegate method
            if !AuthService.shared.isAuthenticated {
                PushNotificationManager.shared.pendingRequestId = reqId
            } else {
                // If authenticated, post notification immediately (app launched from terminated state)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .partnerRequestOpen, object: nil, userInfo: ["requestId": reqId])
                }
            }
        }
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushNotificationManager.shared.didReceiveDeviceToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register: \(error.localizedDescription)")
    }
}
