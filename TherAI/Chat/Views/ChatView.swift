import SwiftUI

struct ChatView: View {

    @EnvironmentObject private var sidebarViewModel: SlideOutSidebarViewModel

    @StateObject private var viewModel: ChatViewModel
    @StateObject private var dialogueViewModel = DialogueViewModel()

    @FocusState private var isInputFocused: Bool

    @State private var selectedMode: PickerView.ChatMode = .personal
    @State private var dialogueSessionId: UUID? = nil

    private let initialSessionId: UUID?

    private var currentUserId: UUID? { AuthService.shared.currentUser?.id }

    init(sessionId: UUID? = nil) {
        self.initialSessionId = sessionId
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId))
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            if selectedMode == .personal {
                // Personal mode - show chat messages or empty state prompt
                if viewModel.messages.isEmpty {
                    PersonalEmptyStateView(prompt: viewModel.emptyPrompt)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MessagesListView(messages: viewModel.messages)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // Dialogue mode - show empty state or dialogue messages
                if dialogueViewModel.messages.isEmpty {
                    DialogueEmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(dialogueViewModel.messages) { message in
                                DialogueMessageView(
                                    message: message,
                                    currentUserId: UUID(uuidString: AuthService.shared.currentUser?.id.uuidString ?? "")
                                )
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var inputArea: some View {
        Group {
            if selectedMode == .personal {
                InputAreaView(
                    inputText: $viewModel.inputText,
                    isLoading: $viewModel.isLoading,
                    isInputFocused: $isInputFocused,
                    send: {
                        let wasNew = viewModel.sessionId == nil
                        viewModel.sendMessage()
                        if wasNew {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if let sid = viewModel.sessionId {
                                    let newSession = ChatSession(id: sid, title: "Chat")
                                    if !sidebarViewModel.sessions.contains(where: { $0.id == newSession.id }) {
                                        sidebarViewModel.sessions.insert(newSession, at: 0)
                                    }
                                    sidebarViewModel.activeSessionId = sid
                                }
                            }
                        }
                    },
                    stop: {
                        viewModel.stopGeneration()
                    },
                    onCreatedNewSession: { _ in },
                    onSendToPartner: {
                        Task { await sendToPartner() }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: selectedMode)
            }
        }
    }
    var body: some View { configuredMainStack }

    private var configuredMainStack: some View {
        mainStack
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = false
        }
        .onAppear {
            // Keep swipe state and picker mode in sync on appear
            if sidebarViewModel.isDialogueOpen {
                selectedMode = .dialogue
            }
            // Auto-focus input on first appear when in Personal mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if selectedMode == .personal { isInputFocused = true }
            }
        }
        .onChange(of: sidebarViewModel.dragOffset) { _, newValue in
            handleSidebarDragChanged(newValue)
        }
        .onChange(of: sidebarViewModel.isOpen) { _, newValue in
            handleSidebarIsOpenChanged(newValue)
        }
        .onAppear { configureCallbacksOnAppear() }
        .onChange(of: sidebarViewModel.activeSessionId) { _, newSessionId in
            handleActiveSessionChanged(newSessionId)
        }
        .onChange(of: sidebarViewModel.isDialogueOpen) { _, newValue in
            // Swiping left/right toggles this flag; mirror it to the picker mode
            if newValue {
                // Dismiss keyboard immediately when entering dialogue
                withAnimation(nil) { isInputFocused = false }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    if selectedMode != .dialogue { selectedMode = .dialogue }
                }
                // Load messages for current active session when entering dialogue
                Task {
                    if let sid = sidebarViewModel.activeSessionId { await dialogueViewModel.loadDialogueMessages(sourceSessionId: sid) }
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    if selectedMode == .dialogue { selectedMode = .personal }
                }
            }
        }
        .onChange(of: selectedMode) { oldMode, newMode in
            if newMode == .dialogue {
                // Ensure keyboard hides instantly when switching modes via picker/programmatically
                withAnimation(nil) { isInputFocused = false }
                Task {
                    // Always use the currently active personal session to scope dialogue
                    if let sid = sidebarViewModel.activeSessionId { await dialogueViewModel.loadDialogueMessages(sourceSessionId: sid) }
                }
                if !sidebarViewModel.isDialogueOpen { sidebarViewModel.openDialogue() }
            } else if newMode == .personal {
                // If personal mode is selected while the stored session is the dialogue session,
                // clear it so sending creates a fresh personal session for this user.
                if let dId = dialogueSessionId, viewModel.sessionId == dId {
                    viewModel.sessionId = nil
                    Task { await viewModel.loadHistory() }
                }
                if sidebarViewModel.isDialogueOpen { sidebarViewModel.closeDialogue() }
                // Only auto-focus if we did not just come from Dialogue mode
                if oldMode != .dialogue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isInputFocused = true
                    }
                } else {
                    withAnimation(nil) { isInputFocused = false }
                }
            }
            if !sidebarViewModel.isDialogueOpen { sidebarViewModel.openDialogue() }
        }
    }

    @ViewBuilder
    private var mainStack: some View {
        VStack(spacing: 0) {
            headerBar
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .background(Color(.systemBackground))

            contentView

            inputArea
        }
    }

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            Button(action: {
                Haptics.impact(.medium)
                sidebarViewModel.openSidebar()
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            }

            Spacer()

            PickerView(selectedMode: $selectedMode)
                .frame(maxWidth: 200)
                .padding(.top, 10)
            Spacer()

            // Invisible spacer to balance the hamburger button
            Color.clear
                .frame(width: 20, height: 20)
        }
    }

    private func handleSidebarDragChanged(_ newValue: CGFloat) {
        if abs(newValue) > 10 { isInputFocused = false }
    }

    private func handleSidebarIsOpenChanged(_ newValue: Bool) {
        if newValue { isInputFocused = false }
    }

    private func handleActiveSessionChanged(_ newSessionId: UUID?) {
        if let sessionId = newSessionId {
            // Update the personal chat view model to reflect the selected session
            viewModel.sessionId = sessionId
            checkIfDialogueSession(sessionId: sessionId)

            // If we navigated away from the dialogue session, force Personal mode
            if let dId = dialogueSessionId, sessionId != dId, selectedMode == .dialogue {
                selectedMode = .personal
            }
        }
    }

    private func configureCallbacksOnAppear() {
        // Set up sidebar callback to switch to dialogue mode
        sidebarViewModel.onSwitchToDialogue = {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                selectedMode = .dialogue
            }
            if !sidebarViewModel.isDialogueOpen { sidebarViewModel.openDialogue() }
        }

        // Allow the dialogue stream to request switching the UI to Dialogue
        dialogueViewModel.onSwitchToDialogue = nil

        // Set up callback to refresh pending requests when dialogue requests are accepted
        dialogueViewModel.onRefreshPendingRequests = {
            Task { await sidebarViewModel.loadPendingRequests() }
        }

        // Only check if this is a dialogue session if there's an active session
        // Don't auto-switch to dialogue mode on fresh login
        if let sessionId = initialSessionId {
            checkIfDialogueSession(sessionId: sessionId)
        }
    }

    private func handleIsDialogueOpenChanged(_ newValue: Bool) {
        // Swiping left/right toggles this flag; mirror it to the picker mode
        if newValue {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                if selectedMode != .dialogue { selectedMode = .dialogue }
            }
            // Load messages for current active session when entering dialogue
            Task {
                if let sid = sidebarViewModel.activeSessionId { await dialogueViewModel.loadDialogueMessages(sourceSessionId: sid) }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                if selectedMode == .dialogue { selectedMode = .personal }
            }
        }
    }

    private func handleSelectedModeChanged(_ newMode: PickerView.ChatMode) {
        if newMode == .dialogue {
            Task {
                // Always use the currently active personal session to scope dialogue
                if let sid = sidebarViewModel.activeSessionId { await dialogueViewModel.loadDialogueMessages(sourceSessionId: sid) }
            }
            if !sidebarViewModel.isDialogueOpen { sidebarViewModel.openDialogue() }
        } else if newMode == .personal {
            // If personal mode is selected while the stored session is the dialogue session,
            // clear it so sending creates a fresh personal session for this user.
            if let dId = dialogueSessionId, viewModel.sessionId == dId {
                viewModel.sessionId = nil
                Task { await viewModel.loadHistory() }
            }
            if sidebarViewModel.isDialogueOpen { sidebarViewModel.closeDialogue() }
        }
    }

    private func checkIfDialogueSession(sessionId: UUID) {
        // Check if this session is a dialogue session by checking if it has dialogue messages
        Task {
            do {
                guard let accessToken = await AuthService.shared.getAccessToken() else { return }
                let sid = sessionId
                let dialogueMessages = try await BackendService.shared.getDialogueMessages(accessToken: accessToken, sourceSessionId: sid)

                // Record the mapped dialogueSessionId for this source session, but do not auto-switch UI.
                await MainActor.run {
                    dialogueSessionId = dialogueMessages.dialogueSessionId
                }
            } catch {
                // If there's an error getting dialogue messages, it's probably not a dialogue session
                print("Not a dialogue session: \(error)")
            }
        }
    }

    private func sendToPartner() async {
        // Resolve session id; if missing, auto-create a personal session first
        var resolvedSessionId = viewModel.sessionId ?? sidebarViewModel.activeSessionId
        if resolvedSessionId == nil {
            do {
                guard let accessToken = await AuthService.shared.getAccessToken() else {
                    print("[ChatView] sendToPartner aborted: no access token for auto-create")
                    return
                }
                let dto = try await BackendService.shared.createEmptySession(accessToken: accessToken)
                resolvedSessionId = dto.id
                await MainActor.run {
                    viewModel.sessionId = dto.id
                    let session = ChatSession(id: dto.id, title: dto.title)
                    if !sidebarViewModel.sessions.contains(where: { $0.id == session.id }) {
                        sidebarViewModel.sessions.insert(session, at: 0)
                    }
                    sidebarViewModel.activeSessionId = dto.id
                    NotificationCenter.default.post(name: .chatSessionCreated, object: nil, userInfo: [
                        "sessionId": dto.id,
                        "title": dto.title ?? "Chat"
                    ])
                }
                print("[ChatView] Auto-created session for Send to Partner: \(dto.id)")
            } catch {
                print("[ChatView] Failed to auto-create session: \(error)")
                return
            }
        }
        guard let sessionId = resolvedSessionId else { print("[ChatView] sendToPartner aborted: missing sessionId after auto-create"); return }

        // Convert chat messages to chat history format
        let chatHistory = viewModel.messages.map { message in
            ChatHistoryMessage(role: message.isFromUser ? "user" : "assistant", content: message.content)
        }

        print("[ChatView] sendToPartner invoked for sessionId=\(sessionId) with \(chatHistory.count) history msgs")
        await dialogueViewModel.sendToPartner(sessionId: sessionId, chatHistory: chatHistory)
    }
}

#Preview {
    ChatView()
        .environmentObject(SlideOutSidebarViewModel())
}

