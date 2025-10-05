import SwiftUI

struct ChatContentView: View {

    let selectedMode: ChatMode
    let personalMessages: [ChatMessage]
    let emptyPrompt: String
    let onDoubleTapPartnerMessage: (_: Any) -> Void
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void
    let personalPreScrollToken: Int
    let keyboardScrollToken: Int

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
        }
        .animation(.easeOut(duration: 0.15), value: selectedMode)
        .id(animationID)
        .onChange(of: selectedMode) { _, _ in
            animationID = UUID()
        }
    }
}


