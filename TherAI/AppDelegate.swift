import Foundation
import UIKit
import UserNotifications

// AppDelegate to handle push notification callbacks
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Ensure notification delegate is set as early as possible so taps from terminated state are delivered
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
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
