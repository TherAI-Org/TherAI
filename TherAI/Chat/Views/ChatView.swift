import SwiftUI

struct ChatView: View {

    @EnvironmentObject private var sidebarViewModel: SlideOutSidebarViewModel

    @StateObject private var viewModel: ChatViewModel

    @State private var showLinking: Bool = false

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

                Button(action: {
                    showLinking = true
                }) {
                    Image(systemName: "link")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            // Messages list
            messagesList

            inputArea
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { isInputFocused = false })
        .sheet(isPresented: $showLinking) {
            MainLinkView(accessTokenProvider: {
                let session = try await AuthService.shared.client.auth.session
                return session.accessToken
            })
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) {
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputArea: some View {
        let isSendDisabled = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let borderWidth: CGFloat = 1.5
        let cornerRadius: CGFloat = 18
        let sendSize: CGFloat = 40

        return HStack(spacing: 12) {
            // Text field inside a minimal rounded container with subtle outline
            HStack(spacing: 8) {
                TextField("Ask anything", text: $viewModel.inputText)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .onSubmit { viewModel.sendMessage() }
                    .focused($isInputFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.black, lineWidth: borderWidth)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
            )

            // Minimal circular send button
            Button(action: {
                let wasNew = viewModel.sessionId == nil
                viewModel.sendMessage()
                if wasNew {
                    // Reflect creation of a new server session back into sidebar
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
            }) {
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: sendSize, height: sendSize)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: borderWidth)
                        )

                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSendDisabled ? .secondary : .primary)
                }
            }
            .disabled(isSendDisabled)
            .opacity(isSendDisabled ? 0.6 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ChatView()
}

