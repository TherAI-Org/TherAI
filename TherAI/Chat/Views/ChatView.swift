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
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    sidebarViewModel.openSidebar()
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("Chat")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            MessagesListView(messages: viewModel.messages)

            InputAreaView(
                inputText: $viewModel.inputText,
                isInputFocused: $isInputFocused,
                send: {
                    let wasNew = viewModel.sessionId == nil
                    viewModel.sendMessage()
                    if wasNew {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let sid = viewModel.sessionId {
                                let newSession = ChatSession(id: sid, title: "Chat")
                                if !sidebarViewModel.sessions.contains(newSession) {
                                    sidebarViewModel.sessions.insert(newSession, at: 0)
                                }
                                sidebarViewModel.openSession(sid)
                            }
                        }
                    }
                },
                onCreatedNewSession: { _ in }
            )
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { isInputFocused = false })
    }
}

#Preview {
    ChatView()
}

