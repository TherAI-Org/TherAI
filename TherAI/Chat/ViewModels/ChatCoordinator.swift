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

    func handleActiveSessionChanged(
        _ newSessionId: UUID?,
        viewModel: ChatViewModel,
        selectedMode: ChatMode,
        dialogueSessionId: UUID?,
        sessionsViewModel: ChatSessionsViewModel,
        dialogueViewModel: DialogueViewModel,
        setSelectedMode: @escaping (ChatMode) -> Void,
        setDialogueSessionId: @escaping (UUID?) -> Void
    ) {
        if let sessionId = newSessionId {
            Task { await viewModel.presentSession(sessionId) }
            checkIfDialogueSession(sessionId: sessionId, dialogueViewModel: dialogueViewModel, setDialogueSessionId: setDialogueSessionId)

            if let dId = dialogueSessionId, sessionId != dId, selectedMode == .dialogue {
                setSelectedMode(.personal)
            }
        }
    }

    func configureCallbacksOnAppear(
        sessionsViewModel: ChatSessionsViewModel,
        navigationViewModel: SidebarNavigationViewModel,
        dialogueViewModel: DialogueViewModel,
        setSelectedMode: @escaping (ChatMode) -> Void,
        refreshPending: @escaping () -> Void
    ) {
        sessionsViewModel.onSwitchToDialogue = {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                setSelectedMode(.dialogue)
            }
            if !navigationViewModel.isDialogueOpen { navigationViewModel.openDialogue() }
        }

        dialogueViewModel.onSwitchToDialogue = nil

        dialogueViewModel.onRefreshPendingRequests = {
            refreshPending()
        }
    }

    func handleIsDialogueOpenChanged(
        _ newValue: Bool,
        selectedMode: ChatMode,
        navigationViewModel: SidebarNavigationViewModel,
        sessionsViewModel: ChatSessionsViewModel,
        dialogueViewModel: DialogueViewModel,
        setSelectedMode: @escaping (ChatMode) -> Void,
        setInputFocused: @escaping (Bool) -> Void
    ) {
        if newValue {
            setInputFocused(false)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                if selectedMode != .dialogue { setSelectedMode(.dialogue) }
            }
            Task {
                if let sid = sessionsViewModel.activeSessionId { await dialogueViewModel.loadDialogueMessages(sourceSessionId: sid) }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                if selectedMode == .dialogue { setSelectedMode(.personal) }
            }
        }
    }

    func handleSelectedModeChanged(
        oldMode: ChatMode,
        newMode: ChatMode,
        navigationViewModel: SidebarNavigationViewModel,
        sessionsViewModel: ChatSessionsViewModel,
        chatViewModel: ChatViewModel,
        dialogueViewModel: DialogueViewModel,
        dialogueSessionId: UUID?,
        setInputFocused: @escaping (Bool) -> Void,
        setSelectedMode: @escaping (ChatMode) -> Void
    ) {
        if newMode == .dialogue {
            setInputFocused(false)
            Task {
                if let sid = sessionsViewModel.activeSessionId { await dialogueViewModel.loadDialogueMessages(sourceSessionId: sid) }
            }
            if !navigationViewModel.isDialogueOpen { navigationViewModel.openDialogue() }
        } else if newMode == .personal {
            if let dId = dialogueSessionId, chatViewModel.sessionId == dId {
                chatViewModel.sessionId = nil
                Task { await chatViewModel.loadHistory() }
            }
            if navigationViewModel.isDialogueOpen { navigationViewModel.closeDialogue() }
        }
    }

    func checkIfDialogueSession(
        sessionId: UUID,
        dialogueViewModel: DialogueViewModel,
        setDialogueSessionId: @escaping (UUID?) -> Void
    ) {
        Task {
            let did = await dialogueViewModel.getDialogueSessionId(for: sessionId)
            await MainActor.run { setDialogueSessionId(did) }
        }
    }

    func handleAskTherAISelectedSnippet(
        snippet: String,
        navigationViewModel: SidebarNavigationViewModel,
        setSelectedMode: @escaping (ChatMode) -> Void,
        setFocusSnippet: @escaping (String?) -> Void,
        setInputFocused: @escaping (Bool) -> Void
    ) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { setSelectedMode(.personal) }
        if navigationViewModel.isDialogueOpen { navigationViewModel.closeDialogue() }
        setFocusSnippet(snippet)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            setInputFocused(true)
        }
    }

    func sendToPartner(chatViewModel: ChatViewModel, sessionsViewModel: ChatSessionsViewModel, dialogueViewModel: DialogueViewModel) async {
        let resolved = await chatViewModel.ensureSessionId()
        let sessionId = resolved ?? sessionsViewModel.activeSessionId
        if let sid = sessionId {
            await dialogueViewModel.sendToPartner(sessionId: sid)
        }
    }
}


