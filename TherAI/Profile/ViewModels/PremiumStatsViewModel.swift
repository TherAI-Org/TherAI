import Foundation
import SwiftUI

final class PremiumStatsViewModel: ObservableObject {
    @Published var isHealthExpanded: Bool = false
    @Published var isResolvedExpanded: Bool = false
    @Published var isImprovementExpanded: Bool = false

    func toggleHealth() {
        isHealthExpanded.toggle()
    }

    func toggleResolved() {
        if isImprovementExpanded {
            isImprovementExpanded = false
        }
        isResolvedExpanded.toggle()
    }

    func toggleImprovement() {
        if isResolvedExpanded {
            isResolvedExpanded = false
        }
        isImprovementExpanded.toggle()
    }
}


