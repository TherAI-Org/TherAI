import Foundation
import SwiftUI

@MainActor
final class ChatSidebarViewModel: ObservableObject {

    static let shared = ChatSidebarViewModel()

    func handleSidebarDragChanged(_ newValue: CGFloat, setInputFocused: (Bool) -> Void) {
        if abs(newValue) > 10 { setInputFocused(false) }
    }

    func handleSidebarIsOpenChanged(_ newValue: Bool, setInputFocused: (Bool) -> Void) {
        if newValue { setInputFocused(false) }
    }

    func handleActiveSessionChanged(_ newSessionId: UUID?, viewModel: ChatViewModel) {
        if let sessionId = newSessionId {
            Task {
                await viewModel.presentSession(sessionId)
            }
        }
    }
}


