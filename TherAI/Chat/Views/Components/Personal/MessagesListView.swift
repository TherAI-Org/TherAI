import SwiftUI

struct MessagesListView: View {
    let messages: [ChatMessage]
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void
    let preScrollTrigger: Int
    let onPreScrollComplete: (() -> Void)?

    init(
        messages: [ChatMessage],
        isInputFocused: Bool,
        onBackgroundTap: @escaping () -> Void,
        preScrollTrigger: Int = 0,
        onPreScrollComplete: (() -> Void)? = nil
    ) {
        self.messages = messages
        self.isInputFocused = isInputFocused
        self.onBackgroundTap = onBackgroundTap
        self.preScrollTrigger = preScrollTrigger
        self.onPreScrollComplete = onPreScrollComplete
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
            }
            .contentShape(Rectangle())
            .onTapGesture { onBackgroundTap() }
            .scrollBounceBehavior(.always)
            .scrollIndicators(.hidden)
            .onChange(of: preScrollTrigger) { _, _ in
                guard preScrollTrigger > 0 else { return }
                guard let lastId = messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    onPreScrollComplete?()
                }
            }
        }
    }
}