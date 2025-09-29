import SwiftUI

struct ChatContentView: View {
    let selectedMode: PickerView.ChatMode
    let personalMessages: [ChatMessage]
    let dialogueMessages: [DialogueViewModel.DialogueMessage]
    let emptyPrompt: String
    let onDoubleTapPartnerMessage: (DialogueViewModel.DialogueMessage) -> Void
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void

    var body: some View {
        Group {
            if selectedMode == .personal {
                if personalMessages.isEmpty {
                    PersonalEmptyStateView(prompt: emptyPrompt)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 0)
                } else {
                    MessagesListView(messages: personalMessages, isInputFocused: isInputFocused, onBackgroundTap: onBackgroundTap)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                if dialogueMessages.isEmpty {
                    DialogueEmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(dialogueMessages) { message in
                                DialogueMessageView(
                                    message: message,
                                    currentUserId: UUID(uuidString: AuthService.shared.currentUser?.id.uuidString ?? ""),
                                    onDoubleTapPartnerMessage: onDoubleTapPartnerMessage
                                )
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}


