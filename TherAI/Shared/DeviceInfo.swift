import Foundation
import UIKit

struct DeviceInfo {
    /// Check if the device supports iOS 26+ Liquid Glass effects
    static var supportsLiquidGlass: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    /// Check if the device supports glass effects (legacy support)
    static var supportsGlassEffect: Bool {
        if #available(iOS 15.0, *) {
            return true
        }
        return false
    }
    
    /// Get the current iOS version
    static var iOSVersion: String {
        return UIDevice.current.systemVersion
    }
    
    /// Check if running on iOS 26 or later
    static var isiOS26OrLater: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
}
