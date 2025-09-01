import SwiftUI

struct MainChatView: View {
    @StateObject private var viewModel = SessionsViewModel()

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(destination: ChatView(sessionId: session.id)) {
                        Text(session.title ?? "Chat")
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ChatView()) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Chat")
                }
            }
        }
        .onAppear { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
    }
}

#Preview {
    MainChatView()
}