import SwiftUI

struct ChatView: View {

    @EnvironmentObject private var sidebarViewModel: SlideOutSidebarViewModel

    @StateObject private var viewModel: ChatViewModel
    @StateObject private var dialogueViewModel = DialogueViewModel()

    @FocusState private var isInputFocused: Bool

    @State private var selectedMode: PickerView.ChatMode = .personal
    @State private var dialogueSessionId: UUID? = nil

    private let initialSessionId: UUID?

    init(sessionId: UUID? = nil) {
        self.initialSessionId = sessionId
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId))
    }

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .background(Color(.systemBackground))

            ///////////
            // Content based on selected mode
            if selectedMode == .personal {
                // Personal mode - show chat messages
                MessagesListView(messages: viewModel.messages)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Dialogue mode - show dialogue messages
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

            // Input area - only show for personal mode
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
                        Task {
                            await sendToPartner()
                        }
                    }
                )
            }
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = false
        }
        .onChange(of: sidebarViewModel.dragOffset) { _, newValue in
            if abs(newValue) > 10 {
                isInputFocused = false
            }
        }
        .onChange(of: sidebarViewModel.isOpen) { _, newValue in
            if newValue {
                isInputFocused = false
            }
        }
        .onAppear {
            // Set up sidebar callback to switch to dialogue mode
            sidebarViewModel.onSwitchToDialogue = {
                selectedMode = .dialogue
            }

            // Set up callback to refresh pending requests when dialogue requests are accepted
            dialogueViewModel.onRefreshPendingRequests = {
                Task {
                    await sidebarViewModel.loadPendingRequests()
                }
            }

            // Only check if this is a dialogue session if there's an active session
            // Don't auto-switch to dialogue mode on fresh login
            if let sessionId = initialSessionId {
                checkIfDialogueSession(sessionId: sessionId)
            }
        }
        .onChange(of: sidebarViewModel.activeSessionId) { _, newSessionId in
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
        .onChange(of: selectedMode) { _, newMode in
            if newMode == .dialogue {
                Task {
                    // Always use the currently active personal session to scope dialogue
                    if let sid = sidebarViewModel.activeSessionId { await dialogueViewModel.loadDialogueMessages(sourceSessionId: sid) }
                }
            } else if newMode == .personal {
                // If personal mode is selected while the stored session is the dialogue session,
                // clear it so sending creates a fresh personal session for this user.
                if let dId = dialogueSessionId, viewModel.sessionId == dId {
                    viewModel.sessionId = nil
                    Task { await viewModel.loadHistory() }
                }
            }
        }
    }

    private func checkIfDialogueSession(sessionId: UUID) {
        // Check if this session is a dialogue session by checking if it has dialogue messages
        Task {
            do {
                guard let accessToken = await AuthService.shared.getAccessToken() else { return }
                guard let sid = sidebarViewModel.activeSessionId else { return }
                let dialogueMessages = try await BackendService.shared.getDialogueMessages(accessToken: accessToken, sourceSessionId: sid)

                // Only switch if this session is the dialogue session AND there are visible messages
                if dialogueMessages.dialogueSessionId == sessionId && !dialogueMessages.messages.isEmpty {
                    await MainActor.run {
                        dialogueSessionId = sessionId
                        // Ensure personal chat does not try to use the dialogue session id
                        if viewModel.sessionId == sessionId {
                            viewModel.sessionId = nil
                        }
                        selectedMode = .dialogue
                    }
                }
            } catch {
                // If there's an error getting dialogue messages, it's probably not a dialogue session
                print("Not a dialogue session: \(error)")
            }
        }
    }

    private func sendToPartner() async {
        guard let sessionId = viewModel.sessionId else { return }

        // Convert chat messages to chat history format
        let chatHistory = viewModel.messages.map { message in
            ChatHistoryMessage(role: message.isFromUser ? "user" : "assistant", content: message.content)
        }

        await dialogueViewModel.sendToPartner(sessionId: sessionId, chatHistory: chatHistory)
    }
}

#Preview {
    ChatView()
        .environmentObject(SlideOutSidebarViewModel())
}

