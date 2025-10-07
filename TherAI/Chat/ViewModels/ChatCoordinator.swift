import Foundation
import SwiftUI

@MainActor
struct ChatCoordinator {

    static let shared = ChatCoordinator()

    func handleSidebarDragChanged(_ newValue: CGFloat, setInputFocused: (Bool) -> Void) {
        if abs(newValue) > 10 { setInputFocused(false) }
    }

    func handleSidebarIsOpenChanged(_ newValue: Bool, setInputFocused: (Bool) -> Void) {
        if newValue { setInputFocused(false) }
    }

    func handleActiveSessionChanged(_ newSessionId: UUID?, viewModel: ChatViewModel) {
        if let sessionId = newSessionId {
            Task { await viewModel.presentSession(sessionId) }
        }
    }

    func handleAskTherAISelectedSnippet(
        snippet: String,
        navigationViewModel: SidebarNavigationViewModel,
        setFocusSnippet: @escaping (String?) -> Void,
        setInputFocused: @escaping (Bool) -> Void
    ) {
        setFocusSnippet(snippet)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            setInputFocused(true)
        }
    }

    func sendToPartner(chatViewModel: ChatViewModel, sessionsViewModel: ChatSessionsViewModel, customMessage: String? = nil) async {
        let resolved = await chatViewModel.ensureSessionId()
        let sessionId = resolved ?? sessionsViewModel.activeSessionId
        guard let sid = sessionId else { return }
        do {
            guard let accessToken = await AuthService.shared.getAccessToken() else { return }
            let body = BackendService.PartnerRequestBody(message: customMessage ?? (chatViewModel.inputText), session_id: sid)
            // Keep the SSE stream alive by consuming it; otherwise it cancels immediately
            Task.detached {
                let stream = BackendService.shared.streamPartnerRequest(body, accessToken: accessToken)
                for await event in stream {
                    switch event {
                    case .toolStart(_):
                        break
                    case .toolArgs(_):
                        break
                    case .toolDone:
                        break
                    case .token(_):
                        break
                    case .done:
                        return
                    case .error(let msg):
                        print("[PartnerStream][iOS] error=\(msg)")
                        return
                    case .session(_):
                        break
                    case .partnerMessage(_):
                        // No UI change here; partner UI comes from personal chat stream path
                        break
                    }
                }
            }
        }
    }
}


