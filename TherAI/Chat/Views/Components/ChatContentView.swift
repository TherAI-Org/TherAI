import SwiftUI

struct ChatContentView: View {

    let selectedMode: ChatMode
    let personalMessages: [ChatMessage]
    let dialogueMessages: [DialogueViewModel.DialogueMessage]
    let emptyPrompt: String
    let onDoubleTapPartnerMessage: (DialogueViewModel.DialogueMessage) -> Void
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void
    let personalPreScrollToken: Int
    let keyboardScrollToken: Int

    @State private var showPersonalPreScrollOverlay: Bool = false
    @State private var preScrollToken: Int = 0

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
                            isInputFocused: isInputFocused,
                            onBackgroundTap: onBackgroundTap,
                            preScrollTrigger: personalPreScrollToken,
                            keyboardScrollTrigger: keyboardScrollToken,
                            onPreScrollComplete: {
                                withAnimation(.easeInOut(duration: 0.2)) { showPersonalPreScrollOverlay = false }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            .opacity(selectedMode == .personal ? 1 : 0)
            .allowsHitTesting(selectedMode == .personal)
            .zIndex(selectedMode == .personal ? 1 : 0)

            Group {
                if dialogueMessages.isEmpty {
                    DialogueEmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(dialogueMessages) { message in
                                    DialogueMessageView(
                                        message: message,
                                        currentUserId: UUID(uuidString: AuthService.shared.currentUser?.id.uuidString ?? ""),
                                        onDoubleTapPartnerMessage: onDoubleTapPartnerMessage
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollIndicators(.hidden)
                        .onAppear {
                            if let lastId = dialogueMessages.last?.id {
                                DispatchQueue.main.async {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo(lastId, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: dialogueMessages.count) { _, _ in
                            if let lastId = dialogueMessages.last?.id {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .opacity(selectedMode == .dialogue ? 1 : 0)
            .allowsHitTesting(selectedMode == .dialogue)
            .zIndex(selectedMode == .dialogue ? 1 : 0)
        }
    }
}


