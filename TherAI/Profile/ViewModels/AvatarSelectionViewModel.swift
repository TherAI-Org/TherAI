import Foundation
import SwiftUI

@MainActor
class AvatarSelectionViewModel: ObservableObject {

    @Published var options: [AvatarOption]
    @Published var selectedId: Int?
    
    private var originalSelectedId: Int?

    init(options: [AvatarOption] = AvatarOption.defaultOptions(), selectedId: Int? = nil) {
        self.options = options
        self.selectedId = selectedId
        self.originalSelectedId = selectedId
    }

    func select(id: Int) {
        selectedId = id
    }
    
    func save() {
        // Update the original selection to the current selection
        originalSelectedId = selectedId
        // Here you would typically persist the avatar selection
        // For now, we'll just update the local state
    }
    
    func cancel() {
        // Revert to the original selection
        selectedId = originalSelectedId
    }
    
    var hasChanges: Bool {
        return selectedId != originalSelectedId
    }
}