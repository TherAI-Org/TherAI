import SwiftUI

struct ChatView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel

    @StateObject private var viewModel: ChatViewModel
    @StateObject private var dialogueViewModel = DialogueViewModel()

    @FocusState private var isInputFocused: Bool

    @State private var selectedMode: ChatMode = .personal
    @State private var dialogueSessionId: UUID? = nil

    init(sessionId: UUID? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId))
    }

    var body: some View {
        let handleDoubleTapPartnerMessage: (DialogueViewModel.DialogueMessage) -> Void = { tapped in
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { selectedMode = .personal }
            if navigationViewModel.isDialogueOpen { navigationViewModel.closeDialogue() }
        }

        let handleSendToPartner: () -> Void = {
            // Prefer the most recent suggested partner message; fallback to input text
            let latestPartnerText: String? = {
                for msg in viewModel.messages.reversed() {
                    if let content = (msg as ChatMessage).partnerMessageContent, (msg as ChatMessage).isPartnerMessage, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return content
                    }
                }
                return nil
            }()

            let inputTextTrimmed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            let textToSend = latestPartnerText ?? (inputTextTrimmed.isEmpty ? nil : inputTextTrimmed)
            guard let text = textToSend, !text.isEmpty else { return }

            if latestPartnerText == nil { viewModel.inputText = "" }

            Task {
                await ChatCoordinator.shared.sendToPartner(
                    chatViewModel: viewModel,
                    sessionsViewModel: sessionsViewModel,
                    dialogueViewModel: dialogueViewModel,
                    customMessage: text
                )
            }
        }

        return ChatScreenView(
            selectedMode: $selectedMode,
            isInputFocused: $isInputFocused,
            chatViewModel: viewModel,
            dialogueViewModel: dialogueViewModel,
            onDoubleTapPartnerMessage: handleDoubleTapPartnerMessage,
            onSendToPartner: handleSendToPartner
        )
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = false }
        .onAppear {
            if navigationViewModel.isDialogueOpen {
                selectedMode = .dialogue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if selectedMode == .personal && sessionsViewModel.activeSessionId == nil {
                    isInputFocused = true
                }
            }
        }
        .onChange(of: navigationViewModel.dragOffset) { _, newValue in if abs(newValue) > 10 { isInputFocused = false } }
        .onChange(of: navigationViewModel.isOpen) { _, newValue in if newValue { isInputFocused = false } }
        .onAppear {
            ChatCoordinator.shared.configureCallbacksOnAppear(
                sessionsViewModel: sessionsViewModel,
                navigationViewModel: navigationViewModel,
                dialogueViewModel: dialogueViewModel,
                setSelectedMode: { selectedMode = $0 },
                refreshPending: { Task { await sessionsViewModel.loadPendingRequests() } }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AskTherAISelectedSnippet"))) { note in
            if let snippet = note.userInfo?["snippet"] as? String {
                ChatCoordinator.shared.handleAskTherAISelectedSnippet(
                    snippet: snippet,
                    navigationViewModel: navigationViewModel,
                    setSelectedMode: { selectedMode = $0 },
                    setFocusSnippet: { viewModel.focusSnippet = $0 },
                    setInputFocused: { isInputFocused = $0 }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SendPartnerMessageFromBubble"))) { note in
            if let text = note.userInfo?["content"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task {
                    await ChatCoordinator.shared.sendToPartner(
                        chatViewModel: viewModel,
                        sessionsViewModel: sessionsViewModel,
                        dialogueViewModel: dialogueViewModel,
                        customMessage: text
                    )
                }
            }
        }
        .onChange(of: sessionsViewModel.activeSessionId) { _, newSessionId in
            ChatCoordinator.shared.handleActiveSessionChanged(
                newSessionId,
                viewModel: viewModel,
                selectedMode: selectedMode,
                dialogueSessionId: dialogueSessionId,
                sessionsViewModel: sessionsViewModel,
                dialogueViewModel: dialogueViewModel,
                setSelectedMode: { selectedMode = $0 },
                setDialogueSessionId: { dialogueSessionId = $0 }
            )
        }
        .onChange(of: sessionsViewModel.chatViewKey) { _, _ in
            if sessionsViewModel.activeSessionId == nil {
                viewModel.sessionId = nil
                Task { await viewModel.loadHistory() }
            }
        }
        .onChange(of: navigationViewModel.isDialogueOpen) { _, newValue in
            ChatCoordinator.shared.handleIsDialogueOpenChanged(
                newValue,
                selectedMode: selectedMode,
                navigationViewModel: navigationViewModel,
                sessionsViewModel: sessionsViewModel,
                dialogueViewModel: dialogueViewModel,
                setSelectedMode: { selectedMode = $0 },
                setInputFocused: { isInputFocused = $0 }
            )
        }
        .onChange(of: selectedMode) { oldMode, newMode in
            ChatCoordinator.shared.handleSelectedModeChanged(
                oldMode: oldMode,
                newMode: newMode,
                navigationViewModel: navigationViewModel,
                sessionsViewModel: sessionsViewModel,
                chatViewModel: viewModel,
                dialogueViewModel: dialogueViewModel,
                dialogueSessionId: dialogueSessionId,
                setInputFocused: { isInputFocused = $0 },
                setSelectedMode: { selectedMode = $0 }
            )
        }
    }


}

#Preview {
    ChatView()
        .environmentObject(SidebarNavigationViewModel())
        .environmentObject(ChatSessionsViewModel())
}

