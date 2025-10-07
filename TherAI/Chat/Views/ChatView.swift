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
            Task { await ChatCoordinator.shared.sendToPartner(chatViewModel: viewModel, sessionsViewModel: sessionsViewModel, customMessage: text) }
        }

        return ChatScreenView(
            isInputFocused: $isInputFocused,
            chatViewModel: viewModel,
            onDoubleTapPartnerMessage: { _ in },
            onSendToPartner: handleSendToPartner
        )
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = false }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if sessionsViewModel.activeSessionId == nil {
                    isInputFocused = true
                }
            }
        }
        .onChange(of: navigationViewModel.dragOffset) { _, newValue in if abs(newValue) > 10 { isInputFocused = false } }
        .onChange(of: navigationViewModel.isOpen) { _, newValue in if newValue { isInputFocused = false } }
        .onAppear {
            Task { await sessionsViewModel.loadPendingRequests() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AskTherAISelectedSnippet"))) { note in
            if let snippet = note.userInfo?["snippet"] as? String {
                ChatCoordinator.shared.handleAskTherAISelectedSnippet(
                    snippet: snippet,
                    navigationViewModel: navigationViewModel,
                    setFocusSnippet: { viewModel.focusSnippet = $0 },
                    setInputFocused: { isInputFocused = $0 }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SendPartnerMessageFromBubble"))) { note in
            if let text = note.userInfo?["content"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task {
                    await ChatCoordinator.shared.sendToPartner(chatViewModel: viewModel, sessionsViewModel: sessionsViewModel, customMessage: text)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SkipPartnerDraftRequested"))) { _ in
            viewModel.requestNewPartnerDraft()
        }
        .onChange(of: sessionsViewModel.activeSessionId) { _, newSessionId in
            if let sid = newSessionId { Task { await viewModel.presentSession(sid) } }
        }
        .onChange(of: sessionsViewModel.chatViewKey) { _, _ in
            if sessionsViewModel.activeSessionId == nil {
                viewModel.sessionId = nil
                Task { await viewModel.loadHistory() }
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

