import Foundation
import UIKit

enum Haptics {

    private static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: PreferenceKeys.hapticsEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: PreferenceKeys.hapticsEnabled)
    }

    // Throttled streaming feedback at constant medium intensity
    private static var lastStreamTickTime: CFTimeInterval = 0
    private static let streamTickMinInterval: CFTimeInterval = 0.02 // ~50 Hz max
    private static var streamImpactGenerator: UIImpactFeedbackGenerator?

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func streamBegin() {
        guard isEnabled else { return }
        streamImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
        streamImpactGenerator?.prepare()
        lastStreamTickTime = 0
    }

    static func streamEnd() {
        streamImpactGenerator = nil
        lastStreamTickTime = 0
    }

    static func streamTick() {
        guard isEnabled else { return }
        let now = CACurrentMediaTime()
        if now - lastStreamTickTime < streamTickMinInterval { return }
        if streamImpactGenerator == nil { streamImpactGenerator = UIImpactFeedbackGenerator(style: .medium) }
        streamImpactGenerator?.prepare()
        if #available(iOS 13.0, *) {
            streamImpactGenerator?.impactOccurred(intensity: 0.8)
        } else {
            streamImpactGenerator?.impactOccurred()
        }
        lastStreamTickTime = now
    }
}


