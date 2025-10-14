import SwiftUI

struct ChatContentView: View {

    let personalMessages: [ChatMessage]
    @ObservedObject var chatViewModel: ChatViewModel
    let emptyPrompt: String
    let onDoubleTapPartnerMessage: (_: Any) -> Void
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void
    let personalPreScrollToken: Int
    let keyboardScrollToken: Int
    var isAssistantTyping: Bool = false
    var focusTopId: UUID? = nil
    var streamingScrollToken: Int = 0
    var streamingTargetId: UUID? = nil

    @State private var showPersonalPreScrollOverlay: Bool = false
    @State private var preScrollToken: Int = 0
    @State private var animationID = UUID()

    var body: some View {
        ZStack {
            Group {
                if personalMessages.isEmpty {
                    PersonalEmptyStateView(prompt: emptyPrompt)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 0)
                } else {
                    ZStack {
                        MessagesListView(
                            messages: personalMessages,
                            chatViewModel: chatViewModel,
                            isInputFocused: isInputFocused,
                            onBackgroundTap: onBackgroundTap,
                            preScrollTrigger: personalPreScrollToken,
                            keyboardScrollTrigger: keyboardScrollToken,
                            onPreScrollComplete: {
                                withAnimation(.easeInOut(duration: 0.2)) { showPersonalPreScrollOverlay = false }
                            },
                            isAssistantTyping: isAssistantTyping,
                            focusTopId: focusTopId,
                            streamingScrollToken: streamingScrollToken,
                            streamingTargetId: streamingTargetId
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Removed global overlay indicator; indicator will appear in message area instead.

                        if showPersonalPreScrollOverlay {
                            PersonalEmptyStateView(prompt: emptyPrompt)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemBackground))
                                .transition(.opacity)
                        }
                    }
                    .onChange(of: personalPreScrollToken) { _, newVal in
                        if newVal > 0 { showPersonalPreScrollOverlay = true }
                    }
                }
            }
            .opacity(1)
            .allowsHitTesting(true)
            .zIndex(1)
        }
        .animation(.easeOut(duration: 0.15), value: personalMessages.count)
        .id(animationID)
        .onChange(of: personalMessages.count) { _, _ in animationID = UUID() }
    }
}


