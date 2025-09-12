import SwiftUI

struct ChatView: View {

    @EnvironmentObject private var sidebarViewModel: SlideOutSidebarViewModel

    @StateObject private var viewModel: ChatViewModel

    @FocusState private var isInputFocused: Bool

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

                Text("Session")
                    .font(Typography.title2)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            // Messages area that takes available space but leaves room for input
            MessagesListView(messages: viewModel.messages)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Input area that stays at the bottom
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
                                let newSession = ChatSession(id: sid, title: "Session")
                                if !sidebarViewModel.sessions.contains(newSession) {
                                    sidebarViewModel.sessions.insert(newSession, at: 0)
                                }
                                // Don't call openSession here as it recreates the ChatView
                                // Just update the activeSessionId without changing chatViewKey
                                sidebarViewModel.activeSessionId = sid
                            }
                        }
                    }
                },
                stop: {
                    viewModel.stopGeneration()
                },
                onCreatedNewSession: { _ in }
            )
        }
        .background(Color(.systemBackground))
        .onChange(of: sidebarViewModel.dragOffset) { _, newValue in
            // Dismiss keyboard when sidebar drag starts (when drag offset becomes non-zero)
            if abs(newValue) > 10 {
                isInputFocused = false
            }
        }
        .onChange(of: sidebarViewModel.isOpen) { _, newValue in
            // Dismiss keyboard when sidebar opens
            if newValue {
                isInputFocused = false
            }
        }
    }
}

#Preview {
    ChatView()
}

