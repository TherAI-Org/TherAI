import SwiftUI
import Combine

struct MessagesListView: View {
    let messages: [ChatMessage]
    @AppStorage(PreferenceKeys.autoScrollEnabled) private var autoScrollEnabled: Bool = true
    let isInputFocused: FocusState<Bool>.Binding

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
                .padding(.bottom, 60) // Very small gap - messages almost next to typing field
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) {
                guard autoScrollEnabled else { return }
                if let lastMessage = messages.last {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(lastMessage.id, anchor: .top)
                    }
                }
            }
            // Also scroll when the last message's content changes during streaming
            .onChange(of: messages.last?.content ?? "") { _, _ in
                guard autoScrollEnabled else { return }
                if let lastMessage = messages.last {
                    withAnimation(.linear(duration: 0.15)) {
                        proxy.scrollTo(lastMessage.id, anchor: .top)
                    }
                }
            }
            // Auto-scroll to bottom when messages are first loaded
            .onAppear {
                guard autoScrollEnabled, !messages.isEmpty else { return }
                if let lastMessage = messages.last {
                    // Single scroll attempt to show last message properly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .top)
                        }
                    }
                }
            }
            // Listen for scroll to bottom notification
            .onReceive(NotificationCenter.default.publisher(for: .scrollToBottom)) { _ in
                guard autoScrollEnabled, !messages.isEmpty else { return }
                if let lastMessage = messages.last {
                    // Single scroll attempt to show last message properly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .top)
                        }
                    }
                }
            }
            // Handle keyboard appearance/disappearance
            .onChange(of: isInputFocused) { _, newValue in
                guard autoScrollEnabled, !messages.isEmpty else { return }
                if let lastMessage = messages.last {
                    if newValue {
                        // Keyboard appearing - scroll up to make room
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .top)
                            }
                        }
                    } else {
                        // Keyboard disappearing - adjust position
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }
}
