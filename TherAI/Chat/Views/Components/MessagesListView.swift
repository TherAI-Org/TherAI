import SwiftUI

struct MessagesListView: View {
    let messages: [ChatMessage]
    @AppStorage(PreferenceKeys.autoScrollEnabled) private var autoScrollEnabled: Bool = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) {
                guard autoScrollEnabled else { return }
                if let lastMessage = messages.last {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    MessagesListView(messages: [
        ChatMessage(content: "Hello!", isFromUser: true),
        ChatMessage(content: "Hi there!", isFromUser: false)
    ])
}