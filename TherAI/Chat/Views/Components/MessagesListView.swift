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
                            .id(message.id)
                    }
                }
                .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) {
                guard autoScrollEnabled else { return }
                if let lastMessage = messages.last {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            // Also scroll when the last message's content changes during streaming
            .onChange(of: messages.last?.content ?? "") { _, _ in
                guard autoScrollEnabled else { return }
                if let lastMessage = messages.last {
                    withAnimation(.linear(duration: 0.15)) {
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