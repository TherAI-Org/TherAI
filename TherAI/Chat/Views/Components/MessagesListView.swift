import SwiftUI

struct MessagesListView: View {
    let messages: [ChatMessage]
    @ObservedObject var chatViewModel: ChatViewModel
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void
    let preScrollTrigger: Int
    let keyboardScrollTrigger: Int
    let onPreScrollComplete: (() -> Void)?
    let isAssistantTyping: Bool
    let focusTopId: UUID?
    let streamingScrollToken: Int
    let streamingTargetId: UUID?
    let initialJumpToken: Int

    @State private var savedScrollPosition: UUID?

    init(
        messages: [ChatMessage],
        chatViewModel: ChatViewModel,
        isInputFocused: Bool,
        onBackgroundTap: @escaping () -> Void,
        preScrollTrigger: Int = 0,
        keyboardScrollTrigger: Int = 0,
        onPreScrollComplete: (() -> Void)? = nil,
        isAssistantTyping: Bool = false,
        focusTopId: UUID? = nil,
        streamingScrollToken: Int = 0,
        streamingTargetId: UUID? = nil,
        initialJumpToken: Int = 0
    ) {
        self.messages = messages
        self.chatViewModel = chatViewModel
        self.isInputFocused = isInputFocused
        self.onBackgroundTap = onBackgroundTap
        self.preScrollTrigger = preScrollTrigger
        self.keyboardScrollTrigger = keyboardScrollTrigger
        self.onPreScrollComplete = onPreScrollComplete
        self.isAssistantTyping = isAssistantTyping
        self.focusTopId = focusTopId
        self.streamingScrollToken = streamingScrollToken
        self.streamingTargetId = streamingTargetId
        self.initialJumpToken = initialJumpToken
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubbleView(message: message, chatViewModel: chatViewModel, onSendToPartner: { text in
                            NotificationCenter.default.post(name: .init("SendPartnerMessageFromBubble"), object: nil, userInfo: ["content": text])
                        })
                            .id(message.id)
                            .padding(.top, index > 0 && (messages[index - 1].isFromUser != message.isFromUser) ? 4 : 0)
                    }
                    if isAssistantTyping {
                        HStack(alignment: .top, spacing: 0) {
                            TypingIndicatorView(showAfter: 0)
                                .padding(.top, -10) // nudge slightly higher to align with message start
                            Spacer(minLength: 0)
                        }
                        .id("typing-indicator")
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal)
            }
            .scrollBounceBehavior(.always)
            .scrollIndicators(.visible)
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
            // First-open jump to bottom without animation
            .onChange(of: initialJumpToken) { _, token in
                guard token > 0 else { return }
                guard let lastId = messages.last?.id else { return }
                // Non-animated to avoid visible scroll
                withAnimation(nil) { proxy.scrollTo(lastId, anchor: .bottom) }
            }
            // Removed one-time push after send
            .onChange(of: isInputFocused) { oldValue, newValue in
                if newValue && !oldValue {
                    guard let lastId = messages.last?.id else { return }

                    savedScrollPosition = lastId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.94)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                } else if !newValue && oldValue, let savedId = savedScrollPosition {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let currentLastId = messages.last?.id
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                            if let currentLastId = currentLastId, currentLastId != savedId {
                                proxy.scrollTo(currentLastId, anchor: .bottom)
                            } else {
                                proxy.scrollTo(savedId, anchor: .bottom)
                            }
                        }
                        savedScrollPosition = nil
                    }
                }
            }
            // Disabled streaming auto-scroll to prevent list jumps after sending
            .onChange(of: streamingScrollToken) { _, _ in
                // no-op: keep current scroll position stable
            }
        }
    }
}