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

        return NavigationStack {
            ChatScreenView(
                chatViewModel: viewModel,
                onSendToPartner: handleSendToPartner,
                isInputFocused: $isInputFocused
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        Haptics.impact(.medium)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        navigationViewModel.openSidebar()
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                .frame(width: 44, height: 44)

                            let unreadCount = sessionsViewModel.unreadPartnerSessionIds.count + sessionsViewModel.pendingRequests.count
                            if unreadCount > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    Text("\(min(unreadCount, 99))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(1)
                                }
                                .frame(width: 16, height: 16)
                                .offset(x: -5, y: 5)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Haptics.impact(.light)
                        sessionsViewModel.startNewChat()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            .frame(width: 44, height: 44)
                            .offset(y: -1.5)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = false }
        .onAppear {
            // Do not focus input when sidebar is open
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
        .onChange(of: navigationViewModel.dragOffset, initial: false) { _, newValue in ChatSidebarViewModel.shared.handleSidebarDragChanged(newValue, setInputFocused: { isInputFocused = $0 }) }
        .onChange(of: navigationViewModel.isOpen, initial: false) { _, newValue in ChatSidebarViewModel.shared.handleSidebarIsOpenChanged(newValue, setInputFocused: { isInputFocused = $0 }) }
        .onAppear {
            Task { await sessionsViewModel.loadPendingRequests() }
            // Register this ChatViewModel with SessionsViewModel so it can preload cache
            sessionsViewModel.chatViewModel = viewModel
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SendPartnerMessageFromBubble"))) { note in
            if let text = note.userInfo?["content"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { await viewModel.sendToPartner(sessionsViewModel: sessionsViewModel, customMessage: text) }
            }
        }
        // SkipPartnerDraftRequested no-op removed; feature not in use
        .onChange(of: sessionsViewModel.chatViewKey, initial: false) { _, _ in
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

