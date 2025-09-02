import Foundation
import SwiftUI

@MainActor
class AvatarSelectionViewModel: ObservableObject {

    @Published var options: [AvatarOption]
    @Published var selectedId: Int?

    init(options: [AvatarOption] = AvatarOption.defaultOptions(), selectedId: Int? = nil) {
        self.options = options
        self.selectedId = selectedId
    }

    func select(id: Int) {
        selectedId = id
    }
}