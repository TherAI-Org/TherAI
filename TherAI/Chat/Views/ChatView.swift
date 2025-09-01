import SwiftUI

struct ChatView: View {

    private let initialSessionId: UUID?
    @StateObject private var viewModel: ChatViewModel

    @State private var showSettings = false
    @State private var isSigningOut = false

    init(sessionId: UUID? = nil) {
        self.initialSessionId = sessionId
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            messagesList

            inputArea
        }
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink(destination: MainChatView()) {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("Chats")
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                Form {
                    Section(header: Text("Account")) {
                        Button(role: .destructive) {
                            isSigningOut = true
                            Task { await AuthService.shared.signOut(); isSigningOut = false; showSettings = false }
                        } label: {
                            if isSigningOut { ProgressView() } else { Text("Sign Out") }
                        }
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
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
        HStack(spacing: 12) {
            TextField("Type a message...", text: $viewModel.inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button(action: {
                viewModel.sendMessage()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

#Preview {
    ChatView()
}

