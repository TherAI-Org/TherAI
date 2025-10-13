import Foundation

#if canImport(UIKit)
import UIKit

final class BackgroundTaskManager {

    static let shared = BackgroundTaskManager()

    private init() {}

    func begin(name: String, onExpire: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier {
        var identifier: UIBackgroundTaskIdentifier = .invalid
        let work = {
            identifier = UIApplication.shared.beginBackgroundTask(withName: name) {
                onExpire?()
                UIApplication.shared.endBackgroundTask(identifier)
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync { work() }
        }
        return identifier
    }

    func end(_ identifier: UIBackgroundTaskIdentifier?) {
        guard let id = identifier, id != .invalid else { return }
        DispatchQueue.main.async {
            UIApplication.shared.endBackgroundTask(id)
        }
    }
}

#else

// Non-UIKit platforms: provide no-op stubs
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private init() {}
    func begin(name: String) -> Int { return 0 }
    func end(_ identifier: Int?) {}
}

#endif


