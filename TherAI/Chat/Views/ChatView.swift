import SwiftUI

struct ChatView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel

    @StateObject private var viewModel: ChatViewModel

    @FocusState private var isInputFocused: Bool

    init(sessionId: UUID? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId))
    }

    var body: some View {
        let handleSendToPartner: () -> Void = {
            let latestPartnerText = findLatestPartnerMessage()
            let inputTextTrimmed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            let textToSend = latestPartnerText ?? (inputTextTrimmed.isEmpty ? nil : inputTextTrimmed)
            guard let text = textToSend, !text.isEmpty else { return }
            if latestPartnerText == nil { viewModel.inputText = "" }
            Task { await viewModel.sendToPartner(sessionsViewModel: sessionsViewModel, customMessage: text) }
        }

        return ChatScreenView(
            chatViewModel: viewModel,
            onSendToPartner: handleSendToPartner,
            isInputFocused: $isInputFocused
        )
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = false }
        .onAppear {
            if navigationViewModel.isOpen {
                isInputFocused = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if sessionsViewModel.activeSessionId == nil && !navigationViewModel.isOpen {
                        isInputFocused = true
                    }
                }
            }
        }
        .onChange(of: navigationViewModel.dragOffset) { _, newValue in ChatSidebarViewModel.shared.handleSidebarDragChanged(newValue, setInputFocused: { isInputFocused = $0 }) }
        .onChange(of: navigationViewModel.isOpen) { _, newValue in ChatSidebarViewModel.shared.handleSidebarIsOpenChanged(newValue, setInputFocused: { isInputFocused = $0 }) }
        .onAppear {
            Task { await sessionsViewModel.loadPendingRequests() }
            sessionsViewModel.chatViewModel = viewModel
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SendPartnerMessageFromBubble"))) { note in
            if let text = note.userInfo?["content"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { await viewModel.sendToPartner(sessionsViewModel: sessionsViewModel, customMessage: text) }
            }
        }
        .onChange(of: sessionsViewModel.chatViewKey) { _, _ in
            if sessionsViewModel.activeSessionId == nil {
                viewModel.sessionId = nil
                Task { await viewModel.loadHistory() }
            } else {
                ChatSidebarViewModel.shared.handleActiveSessionChanged(sessionsViewModel.activeSessionId, viewModel: viewModel)
            }
        }
    }

    private func findLatestPartnerMessage() -> String? {
        for msg in viewModel.messages.reversed() {
            if let content = (msg as ChatMessage).partnerMessageContent,
               (msg as ChatMessage).isPartnerMessage,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            }
        }
        return nil
    }
}

#Preview {
    ChatView()
        .environmentObject(SidebarNavigationViewModel())
        .environmentObject(ChatSessionsViewModel())
}

