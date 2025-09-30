import SwiftUI

struct ChatContentView: View {

    let selectedMode: ChatMode
    let personalMessages: [ChatMessage]
    let dialogueMessages: [DialogueViewModel.DialogueMessage]
    let emptyPrompt: String
    let onDoubleTapPartnerMessage: (DialogueViewModel.DialogueMessage) -> Void
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void

    @State private var showPersonalPreScrollOverlay: Bool = false
    @State private var preScrollToken: Int = 0

    var body: some View {
        Group {
            if selectedMode == .personal {
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
                            preScrollTrigger: preScrollToken,
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
                    .onAppear {
                        // When arriving with messages, run pre-scroll once
                        if !personalMessages.isEmpty {
                            showPersonalPreScrollOverlay = true
                            preScrollToken &+= 1
                        }
                    }
                    .onChange(of: selectedMode) { _, newMode in
                        guard newMode == .personal else { return }
                        if !personalMessages.isEmpty {
                            showPersonalPreScrollOverlay = true
                            preScrollToken &+= 1
                        }
                    }
                }
            } else {
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
        }
    }
}


