import SwiftUI

struct MessagesListView: View {
    let messages: [ChatMessage]
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void
    let preScrollTrigger: Int
    let keyboardScrollTrigger: Int
    let onPreScrollComplete: (() -> Void)?

    @State private var savedScrollPosition: UUID?

    init(
        messages: [ChatMessage],
        isInputFocused: Bool,
        onBackgroundTap: @escaping () -> Void,
        preScrollTrigger: Int = 0,
        keyboardScrollTrigger: Int = 0,
        onPreScrollComplete: (() -> Void)? = nil
    ) {
        self.messages = messages
        self.isInputFocused = isInputFocused
        self.onBackgroundTap = onBackgroundTap
        self.preScrollTrigger = preScrollTrigger
        self.keyboardScrollTrigger = keyboardScrollTrigger
        self.onPreScrollComplete = onPreScrollComplete
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, onSendToPartner: { text in
                            NotificationCenter.default.post(name: .init("SendPartnerMessageFromBubble"), object: nil, userInfo: ["content": text])
                        })
                            .id(message.id)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal)
            }
            .contentShape(Rectangle())
            .onTapGesture { onBackgroundTap() }
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
            .onChange(of: messages.count) { _, _ in
                guard let lastId = messages.last?.id else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}